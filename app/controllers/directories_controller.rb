class DirectoriesController < ApplicationController
  def index
    render json: DirectoryBrowser.list(params[:path])
  rescue ArgumentError, SystemCallError => e
    render json: { error: "Cannot open this folder: #{e.message}" }, status: :unprocessable_entity
  end
end
