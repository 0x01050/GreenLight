require "rails_helper"

describe MainController, type: :controller do

  describe "GET #index" do
    it "returns success" do
      get :index
      expect(response).to be_successful
    end
  end
end
