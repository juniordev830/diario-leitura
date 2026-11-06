class SessionsController < ApplicationController
 def create
  book = Book.find(params[:book_id])
  page = Integer(params.require(:ending_page), exception: false)
  if page.nil?
   render json: { error: "Página deve ser um número inteiro" }, status: :unprocessable_entity
   return
  end
  note = params[:note].to_s
  result = nil
  book.with_lock do
   if page <= book.current_page || page > book.total_pages
    result = { error: "Página precisa avançar e não ultrapassar o total" }
   elsif note.length > 2000
    result = { error: "Anotação muito longa" }
   else
    session = book.reading_sessions.create!(ending_page: page, note: note)
    book.update!(current_page: page)
    result = { id: session.id, current_page: book.current_page, progress_percent: book.progress_percent }
   end
  end
  render json: result, status: result.key?(:error) ? :unprocessable_entity : :created
 end
end
