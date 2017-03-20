require 'asana'

module Timer
  def self.time(context: '', &block)
    p "#{context} Started".strip
    started_at = Time.now.to_f
    yield
    ended_at = Time.now.to_f
    p "#{context} Ended. Took #{ended_at - started_at} seconds".strip
  end
end

class Project
  def initialize(client:, project_id:)
    @client = client
    @project_id = project_id
  end

  def reload
    @tasks = Asana::Resources::Task.find_all(client, project: project_id, completed_since: Time.now.iso8601, options: { fields: %i(name assignee) })
  end

  def tasks
    @tasks || reload
  end

  def game_time
    tasks.elements[game_time_range]
  end

  def game_time_sorter
    TaskSorter.new(project_id: project_id, tasks: game_time)
  end

  private

  attr_reader :client, :project_id

  def game_time_range
    (label_indexes[0] + 1)..(label_indexes[1] - 1)
  end

  def label_indexes
    @label_indexes ||= tasks.each_with_index.select { |x| x.first.name&.end_with? ':' }.map(&:last).take(2)
  end
end

class TaskSorter
  SLEEP_DURATION = 0.5.freeze

  def initialize(project_id:, tasks:)
    @project_id = project_id
    @tasks = tasks
  end

  def sort!
    raise 'Can only sort once!' if @sorted

    swapped!
    while @swapped do
      @swapped = false
      (0..tasks.length-2).each &bubble_sort_proc
      (0..tasks.length-2).reverse_each &bubble_sort_proc
    end
    @sorted = true
  end

  def swap_with_next!(before_index)
    index = before_index + 1
    task = tasks[index]
    before_task = tasks[before_index]
    Timer.time(context: 'API Call') { task.add_project(project: project_id, insert_before: before_task.id) }
    tasks.delete_at(index)
    tasks.insert(before_index, task)
    sleep SLEEP_DURATION
  end

  private

  attr_reader :project_id, :tasks

  def bubble_sort_proc
    Proc.new do |i|
      task = tasks[i]
      next_task = tasks[i+1]

      task_assignee_id = task.assignee && task.assignee['id'] || 0
      next_task_assignee_id = next_task.assignee && next_task.assignee['id'] || 0

      if (task_assignee_id > next_task_assignee_id)
        swap_with_next!(i)
        swapped!
      end
    end
  end

  def swapped!
    @swapped = true
  end
end

PROD_GAME_TIME = 251561739919560.freeze
PLAYGROUND = 297610249626930.freeze

client = Asana::Client.new do |c|
  c.authentication :access_token, '0/3c6ebb91310cc40fb8fe097fb7d12d26'
end

project = Project.new(client: client, project_id: PROD_GAME_TIME)
sorter = project.game_time_sorter

Timer.time(context: 'Sorting') { sorter.sort! }
