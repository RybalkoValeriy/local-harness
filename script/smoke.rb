abort "Set LM_STUDIO_URL before running" if ENV["LM_STUDIO_URL"].blank?
puts "Available models: #{LmStudio.new.models.join(', ')}"
conversation = Conversation.create!(title: "First local workspace test")
AgentRunner.new(conversation).run("Read README.md using read_file and explain in one sentence what this workspace is for.") do |type, payload|
  puts({ type: type, **payload }.to_json) unless type == "reasoning"
end
abort "Tool call was not exercised" unless conversation.messages.where(role: "tool").exists?
puts "PASS: live local model, tools, persistence, and agent loop. Conversation #{conversation.id}"
