class BooksController < ApplicationController
 def index
  render json: Book.order(:id).map { |b| summary(b) }
 end
 def create
  book = Book.new(book_params)
  if book.save
   render json: summary(book), status: :created
  else
   render json: { errors: book.errors.full_messages }, status: :unprocessable_entity
  end
 end
 def show
  book = Book.find(params[:id])
  render json: summary(book).merge(sessions: book.reading_sessions.order(:id).as_json(only: [:id, :ending_page, :note, :created_at]))
 end
 private
 def book_params
  params.permit(:title, :total_pages, :goal_pages)
 end
 def summary(book)
  { id: book.id, title: book.title, total_pages: book.total_pages, current_page: book.current_page, goal_pages: book.goal_pages, progress_percent: book.progress_percent }
 end
end
