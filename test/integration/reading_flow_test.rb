require "test_helper"
class ReadingFlowTest < ActionDispatch::IntegrationTest
 test "duas sessões atualizam progresso e rejeitam ultrapassar páginas" do
  post "/books", params: { title: "Livro exemplo", total_pages: 120, goal_pages: 100 }
  assert_response :created
  id = response.parsed_body["id"]
  post "/books/#{id}/sessions", params: { ending_page: 20, note: "Início" }
  assert_response :created
  post "/books/#{id}/sessions", params: { ending_page: 50, note: "Segundo dia" }
  assert_response :created
  get "/books/#{id}"
  assert_response :success
  assert_equal 50, response.parsed_body["current_page"]
  assert_equal 2, response.parsed_body["sessions"].size
  post "/books/#{id}/sessions", params: { ending_page: 121 }
  assert_response :unprocessable_entity
  get "/books/#{id}"
  assert_equal 50, response.parsed_body["current_page"]
 end
end
