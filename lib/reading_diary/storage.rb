# frozen_string_literal: true

require "json"
require "tempfile"
require "fileutils"
require_relative "catalog"

module ReadingDiary
  module Storage
    MAX_BYTES = 10 * 1024 * 1024
    module_function

    def load(path)
      check_path!(path)
      return ReadingDiary.empty unless File.exist?(path)
      raise ReadingDiary::Error, "arquivo muito grande" if File.size(path) > MAX_BYTES
      data = JSON.parse(File.read(path, encoding: "UTF-8"))
      ReadingDiary.validate!(data)
    rescue JSON::ParserError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      raise ReadingDiary::Error, "arquivo JSON corrompido ou invalido"
    rescue Errno::EACCES, Errno::EISDIR, Errno::ENOTDIR => error
      raise ReadingDiary::Error, "nao foi possivel ler arquivo: #{error.class}"
    end

    def save(path, state)
      ReadingDiary.validate!(state)
      check_path!(path)
      parent = File.dirname(File.expand_path(path))
      raise ReadingDiary::Error, "diretorio de destino inexistente" unless File.directory?(parent)
      serialized = JSON.pretty_generate(state) + "\n"
      raise ReadingDiary::Error, "arquivo muito grande" if serialized.bytesize > MAX_BYTES
      temporary = nil
      begin
        temporary = Tempfile.create([".diario-", ".tmp"], parent)
        temporary.write(serialized)
        temporary.flush
        temporary.fsync
        temporary.close
        check_path!(path)
        File.rename(temporary.path, path)
        sync_directory(parent)
      ensure
        if temporary
          temporary.close unless temporary.closed?
          File.delete(temporary.path) if File.exist?(temporary.path)
        end
      end
      true
    rescue Errno::EACCES, Errno::ENOSPC, Errno::EROFS, Errno::EISDIR => error
      raise ReadingDiary::Error, "nao foi possivel salvar: #{error.class}"
    end

    def transaction(path)
      raise ReadingDiary::Error, "bloco obrigatorio" unless block_given?
      check_path!(path)
      lock_path = "#{path}.lock"
      raise ReadingDiary::Error, "arquivo de trava invalido" if File.symlink?(lock_path)
      parent = File.dirname(File.expand_path(path))
      raise ReadingDiary::Error, "diretorio de destino inexistente" unless File.directory?(parent)
      File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        state = load(path)
        result = yield(state)
        save(path, state)
        result
      ensure
        lock.flock(File::LOCK_UN)
      end
    rescue Errno::EACCES, Errno::EROFS => error
      raise ReadingDiary::Error, "nao foi possivel obter trava: #{error.class}"
    end

    def backup(path, destination)
      state = load(path)
      raise ReadingDiary::Error, "arquivo de origem inexistente" unless File.file?(path)
      check_path!(destination)
      raise ReadingDiary::Error, "backup ja existe" if File.exist?(destination)
      parent = File.dirname(File.expand_path(destination))
      raise ReadingDiary::Error, "diretorio de destino inexistente" unless File.directory?(parent)
      payload = JSON.pretty_generate(state) + "\n"
      created = false
      begin
        File.open(destination, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
          created = true
          file.write(payload)
          file.flush
          file.fsync
        end
        sync_directory(parent)
      rescue StandardError
        File.delete(destination) if created && File.file?(destination)
        raise
      end
      destination
    rescue Errno::EEXIST
      raise ReadingDiary::Error, "backup ja existe"
    rescue Errno::EACCES, Errno::ENOSPC, Errno::EROFS => error
      raise ReadingDiary::Error, "falha ao criar backup: #{error.class}"
    end

    def check_path!(path)
      raise ReadingDiary::Error, "caminho invalido" unless path.is_a?(String) && !path.empty? && !path.include?("\0")
      raise ReadingDiary::Error, "links simbolicos nao sao permitidos" if File.symlink?(path)
      raise ReadingDiary::Error, "caminho aponta para diretorio" if File.directory?(path)
      true
    end

    def sync_directory(path)
      File.open(path, File::RDONLY) { |directory| directory.fsync }
    rescue Errno::EINVAL, Errno::EBADF, Errno::EISDIR
      # Alguns sistemas nao permitem fsync em diretorios.
      nil
    end
  end
end
