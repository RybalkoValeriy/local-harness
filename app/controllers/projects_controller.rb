class ProjectsController < ApplicationController
  def index
    @projects = Project.order(updated_at: :desc)
    @project = Project.new
  end

  def create
    input = params.require(:project).permit(:name, :path, :mode, :folder)
    @project = ProjectRegistration.call(**input.to_h.symbolize_keys)
    if @project.persisted?
      redirect_to project_path(@project)
    else
      @projects = Project.order(updated_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def show
    @project = Project.find(params[:id])
    @projects = Project.order(:name)
    @conversations = @project.conversations.order(updated_at: :desc)
    @conversation = @conversations.first
    render "conversations/show"
  end
end
