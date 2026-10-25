class ConversationsController < ApplicationController
  include ActionController::Live

  def index
    redirect_to projects_path
  end

  def show
    if params[:project_id].blank?
      conversation = Conversation.find(params[:id])
      return redirect_to project_conversation_path(conversation.project, conversation)
    end
    @project = Project.find(params[:project_id])
    @projects = Project.order(:name)
    @conversations = @project.conversations.order(updated_at: :desc)
    @conversation = @conversations.find(params[:id])
  end

  def create
    project = params[:project_id] ? Project.find(params[:project_id]) : Project.legacy_workspace
    redirect_to project_conversation_path(project, project.conversations.create!), status: :see_other
  end

  def connection
    models = LmStudio.new.models
    render json: { connected: models.include?(LmStudio.model), models: models, model: LmStudio.model }
  rescue LmStudio::Error => e
    render json: { connected: false, error: e.message }, status: :service_unavailable
  end

  def run
    scope = params[:project_id] ? Project.find(params[:project_id]).conversations : Conversation.all
    conversation = scope.find(params[:id])
    response.headers["Content-Type"] = "application/x-ndjson"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"
    emit = ->(type, payload) { response.stream.write({ type: type, **payload }.to_json + "\n") }
    AgentRunner.new(conversation).run(params[:prompt], &emit)
  rescue ActionController::Live::ClientDisconnected, IOError
    # Closing the stream cancels further work; partial turns are omitted on the next request.
  rescue LmStudio::Error, ArgumentError => e
    conversation&.messages&.create!(role: "error", content: e.message)
    emit&.call("error", { message: e.message })
  ensure
    response.stream.close if emit
  end
end
