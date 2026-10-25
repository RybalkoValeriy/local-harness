require "tmpdir"
require "ripper"

$stdout.sync = true

abort "Set LM_STUDIO_URL before running" if ENV["LM_STUDIO_URL"].blank?
Dir.mktmpdir("harness-local-trial-") do |directory|
  Project.transaction do
    project = Project.create!(name: "Temporary RubyLLM file trial", path: directory)
    conversation = project.conversations.create!
    emit = ->(type, data) { puts({ type: type, **data }.to_json) unless %w[token reasoning].include?(type) }
    AgentRunner.new(conversation).run('Use create_file to create hello.rb with exactly this Ruby code: puts "Hello local" followed by a newline. Do not just show code; create the file. Keep your final answer to one sentence.', &emit)
    path = File.join(directory, "hello.rb")
    abort "Creation failed" unless File.file?(path) && File.read(path).include?('puts "Hello local"')
    abort "Created Ruby is invalid" unless Ripper.sexp(File.read(path))
    AgentRunner.new(conversation).run('Read hello.rb, then use edit_file to change Hello local to Hello RubyLLM. Keep the rest unchanged. Do not run commands. Keep your final answer to one sentence.', &emit)
    abort "Editing failed" unless File.read(path).include?('puts "Hello RubyLLM"') && !File.read(path).include?("Hello local")
    abort "Edited Ruby is invalid" unless Ripper.sexp(File.read(path))
    names = conversation.messages.where(role: "tool").map { |message| message.metadata["name"] }
    abort "Missing tool evidence: #{names.inspect}" unless %w[create_file read_file edit_file].all? { |name| names.include?(name) }
    puts "PASS: Qwen via RubyLLM created, read and edited a file; disk contents and persisted tool results verified."
    raise ActiveRecord::Rollback
  end
end
