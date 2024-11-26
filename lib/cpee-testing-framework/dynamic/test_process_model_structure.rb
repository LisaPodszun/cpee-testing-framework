#! /usr/bin/ruby
require "rubygems"
require "json"
require "xml/smart"
require_relative "state_machines"

class ProcessInstance
  attr_accessor :finished

  def initialize(description)
    @description = description
    # All running or done activities
    @activities = []
    # All running activities
    @active_activities = {}
    # All activities marked at
    @at_activities = []
    # All marked activities
    @after_activities = []
    # All unmarked activities
    @unmarked_activities = []
    @active_gateways = {}
    @main_branch = Branch.new(self, description.children, nil, :main)
    @process_ended = false
    @finished = false
    @state_machine = ProcessMachine.new
  end

  def process_event(event, id, content = nil)
    # TODO: Handle state events!
    # TODO: Handle position changes
    topic = event[0]
    event = event[1]
    case topic
    when "activity"
      if @active_activities.key?(id)
        @active_activities[id].event(event)
      else
        p "Cannot process event #{topic}/#{event} for id #{id} as activity is not marked as active"
        # TODO handle error case
      end
    when "gateway"
      if @active_gateways.key?(id)
        @active_gateways[id].event(event, content)
      else
        p "Cannot process event #{topic}/#{event} for id #{id} as gateway is not marked as active"
        # TODO handle error case
      end
    when "position"
      if event == "change"
        unless content["at"].nil?
          content["at"].each do |e|
            activity = e["position"]
            unless @activities.include? activity
              raise "Activity #{activity} is set to at but was not an active activity!"
            end
            @at_activities << activity
          end
        end
        unless content["after"].nil?
          content["after"].each do |e|
            activity = e["position"]
            unless @at_activities.include? activity
              raise "Activity #{activity} is set to after but was not at!"
            end
            @after_activities << activity
          end
        end
        unless content["unmark"].nil?
          content["unmark"].each do |e|
            activity = e["position"]
            unless @after_activities.include? activity
              raise "Activity #{activity} is unmarked but was not marked!"
            end
            @unmarked_activities << activity
          end
        end
      else
        p "Unknown position topic event: #{event}"
      end
    when "state"
      if event == "change"
        new_state = content["state"]
        unless @state_machine.fire_state_event(new_state)
          raise "Cannot transition from process state #{@state_machine.state} to state #{new_state}"
        end
      else
        p "Unknown state event: #{event}"
      end
    else
      p "Cannot handle topic: #{topic} yet. Content: #{content}"
      # TODO handle error case
    end
  end

  def add_active_activity(activity_id, activity_node)
    @activities << activity_id
    if @active_activities.key? activity_id
      p "Key already contained!!!"
      # TODO: Handle error
    end
    @active_activities[activity_id] = activity_node
  end

  def remove_active_activity(activity_id)
    if !@active_activities.key? activity_id
      p "Key not contained!!!"
      # TODO: Handle error
    end
    @active_activities.delete activity_id
  end

  # parallel, decision, loop
  def add_active_gateway(gid, gateway)
    @active_gateways[gid] << gateway
  end

  def remove_active_gateway(gid)
    if !@active_gateways.key? gid
      p "Key not contained!!!"
      # TODO: Handle error
    end
    @active_gateways.delete gid
  end

  def process_ended?
    @process_ended
  end

  def check_for_correctness
    if !@state_machine.finished?
      return false
    end
    @activities.sort!
    @at_activities.sort!
    @after_activities.sort!
    @unmarked_activities.sort!
    if @activities != @at_activities || @at_activities != @after_activities || @after_activities != @unmarked_activities
      p "Activities unequal"
      return false
    end
    if !@main_branch.branch_ended?
      return false
    end
    @main_branch.check_for_correctness
  end
end

# Represents a thread of execution: Main Branch, branches for parallel and choice
class Branch

  # branch_nodes: all direct XML children of the branch
  def initialize(process, branch_nodes, gateway = nil, type)
    # Reference to the overall process object
    @process = process
    @gateway = gateway
    @type = type
    # @branch_id = SecureRandom.hex(5)
    @branch_nodes = branch_nodes
    # Instantiated child nodes
    @structure = []
    @branch_ended = false
    @active_node_index = 0
    @active_node = nil
    self.next_element 0
  end

  # Called by children to notify the branch about their start
  def signal_running(node)
    # Notify the gateway that the first activity in the branch started executing
    if @active_node.nil? && !@gateway.nil?
      @gateway.signal_branch_running self
      @active_node_index = 0
    else
      @active_node_index += 1
    end
    @active_node = node
  end

  # Called by children to notify the branch about their completion
  def signal_end(node)
    if @active_node.id != node.id
      p "Trying to remove non-active node: #{node}"
    end
    if [ScriptCall, ServiceScriptCall, ServiceCall].include? node.class
      @process.remove_active_activity(node.id)
    else
      @process.remove_active_gateway(node)
    end

    next_node_index = @active_node_index + 1

    if next_node_index < @branch_nodes.length
      next_element next_node_index
    else
      @branch_ended = true
      if !@gateway.nil?
        @gateway.signal_branch_end self
      end
    end
  end

  def branch_ended?
    @branch_ended
  end

  def next_element(next_node_index)
    if next_node_index < @branch_nodes.length
      next_element = translate_from_xml(@branch_nodes[next_node_index], self)
      @structure << next_element
      if [ScriptCall, ServiceScriptCall, ServiceCall].include? next_element.class
        @process.add_active_activity next_element.id, next_element
      elsif [ParallelGateway, DecisionGateway].include? next_element.class
        @process.add_active_gateway next_element.gid, next_element
      else
        p "Cannot handle element: #{next_element}"
      end
      @current_elements
    else
      @branch_ended = true
      if !@gateway.nil?
        @gateway.signal_branch_end self
      else
        @process.finished = true
      end
    end
  end

  def check_for_correctness
    # If the branch did nont execute, it is correct
    if @active_node.nil?
      return true
    else
      @structure.map { |node| node.check_for_correctness }.all?
    end
  end
end

# TODO: handle specific error cases differently
class ServiceCall
  attr_reader :id

  def initialize(id, parent)
    @parent = parent
    @id = id
    @state_machine = ServiceCallMachine.new
  end

  def event(type)
    case type
    when "calling"
      if @state_machine.can_call?
        @state_machine.call
        @parent.signal_running self
      else
        raise "ERROR: this #{type} event happens in wrong state : #{@state_machine.state}"
      end
    when "error"
      if @state_machine.can_error?
        @state_machine.error
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
    when "content"
      if @state_machine.can_get_content?
        @state_machine.get_content
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
    when "receiving"
      if @state_machine.can_receive?
        @state_machine.receive
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
    when "done"
      if @state_machine.can_end_activity?
        @state_machine.end_activity
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
      if @state_machine.done?
        @parent.signal_end(self)
      else
        raise "ERROR: state machine is not yet done to signal the end"
      end
    else
      raise "ERROR: Eventtype #{type} not possible for #{self.class}"
    end
  end

  def check_for_correctness
    # Either the activity is executed to completeness or it is not executed at all
    self.activity_done? || @state_machine.ready?
  end

  def activity_done?
    @state_machine.done?
  end
end

class ServiceScriptCall
  attr_reader :id

  def initialize(id, parent)
    @parent = parent
    @id = id
    @state_machine = ServiceScriptCallMachine.new
  end

  def event(type)
    case type
    when "calling"
      if @state_machine.can_call?
        @state_machine.call
        @parent.signal_running self
      else
        raise "ERROR: this #{type} event happens in wrong state"
      end
    when "error"
      if @state_machine.can_error?
        @state_machine.error
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
    when "content"
      if @state_machine.can_get_content?
        @state_machine.get_content
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
    when "receiving"
      if @state_machine.can_receive?
        @state_machine.receive
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
    when "manipulating"
      if @state_machine.can_manipulate?
        @state_machine.manipulate
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
    when "change"
      if @state_machine.can_change_dataelements?
        @state_machine.change_dataelements
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
    when "done"
      if @state_machine.can_end_activity?
        @state_machine.end_activity
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
      if @state_machine.done?
        @parent.signal_end(self)
      else
        raise "ERROR: state machine is not yet done to signal the end"
      end
    else
      "ERROR: Eventtype #{type} not possible for #{self.class}"
    end
  end

  def check_for_correctness
    self.activity_done? || @state_machine.ready?
  end

  def activity_done?
    @state_machine.done?
  end
end

class ScriptCall
  attr_reader :id

  def initialize(id, parent)
    @parent = parent
    @id = id
    @state_machine = ScriptCallMachine.new
  end

  def event(type)
    case type
    when "manipulating"
      if @state_machine.can_manipulate?
        @state_machine.manipulate
        @parent.signal_running self
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
    when "error"
      if @state_machine.can_error?
        @state_machine.error
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
    when "change"
      if @state_machine.can_change_dataelements?
        @state_machine.change_dataelements
        @state_machine.end_activity
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
      if @state_machine.done?
        @parent.signal_end(self)
      else
        raise "ERROR: state machine is not yet done to signal the end"
      end
    else
      "ERROR: Eventtype #{type} not possible for #{self.class}"
    end
  end

  def check_for_correctness
    self.activity_done? || @state_machine.ready?
  end

  def activity_done?
    @state_machine.done?
  end
end

class ParallelGateway
  def initialize(xml_node, process, parent_branch)
    @state_machine = ParallelGatewayMachine.new
    @process = process
    @parent_branch = parent_branch
    @branches = []
    @started_branches = []
    @finished_branches = []
    @wait = xml_node.attributes["wait"]
    # Whether the gateway is already running (at least one branch signaled that it is runnign)
    @running = false
    xml_node.children.each do |parallel_branch_node|
      @branches << translate_from_xml(parallel_branch_node.children, self)
    end
    unless @wait == "-1"
      @wait_on_branches = @wait
      @cancel = xml_node.attributes["cancel"]
    end
  end

  def event(type, content)
    case type
    when "split"
      if @state_machine.can_split?
        @state_machine.split
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
    when "join"
      if @state_machine.can_join?
        @state_machine.join
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
    else
      raise "ERROR: Eventtype #{type} not possible for #{self.class}"
    end
  end

  def done?
    @state_machine.done?
  end

  def signal_branch_running(branch)
    @started_branches << branch
    if !@running
      @running = true
      @parent_branch.signal_running self
    end
  end

  def signal_branch_end(branch)
    @finished_branches << branch
    # {{{
    # For now ignore all this complicated handling of the early termination conditions
    #  unless @wait == ("-1" || "0")
    #    if @cancel == "after_first"
    #      # there are still parallel branches to wait on
    #      if @wait_on_branches - 1 > 0
    #        unless @executing_branches.include?(branch_id)
    #          @wait_on_branches -= 1
    #          @executing_branches << {branch_id:@branches[branch_id]}
    #        end
    #      else
    #      # last branch to wait on has finished the first task
    #        unless @executing_branches.include?(branch_id)
    #          @wait_on_branches -= 1
    #          @executing_branches << {branch_id:@branches[branch_id]}
    #          @branches.keys.each do |branch|
    #            unless @executing_branches.include?(branch)
    #              branch.branch_ended= true
    #            end
    #          end
    #        end
    #      end
    #    else
    #       # there are still parallel branches to wait on
    #      if @wait_on_branches - 1 > 0
    #        if @branches[branch_id].branch_ended?
    #          @wait_on_branches -= 1
    #          @finished_branches << {branch_id:@branches[branch_id]}
    #        end
    #      else
    #        if @branches[branch_id].branch_ended?
    #          @wait_on_branches -= 1
    #          @finished_branches << {branch_id:@branches[branch_id]}
    #          branch_ended= true
    #        end
    #      end
    #    end
    #  else
    #    # wait for all branches and mark all finished branches
    #    if @branches[branch_id].branch_ended?
    #      @finished_branches << {branch_id:@branches[branch_id]}
    #      if @finished_branches == @branches
    #        branch_ended= true
    #      end
    #    end
    #  end
    #  # update finished tasks
    #  @current_elements.delete(task_id)
    #  @parent_process.signal_end_of_task(task_id, branch_id)
    # }}}
  end

  def check_for_correctness
    if !self.done?
      return false
    end
    if @wait == -1
      # All branches have to be finished
      if @branches.length != @branches_finished.length
        return false
      end
    else
      # Not enough branches terminated
      if @branches_finished.length < @wait
        return false
      end
    end
    @branches.map { |branch| branch.check_for_correctness }.all?
  end
end

class DecisionGateway
  def initialize(xml_node, process, parent_branch)
    @state_machine = DecisionGatewayMachine.new
    @process = process
    @parent_branch = parent_branch
    @branches = []
    @chosen_branches = []
    @finished_branches = []
    @mode = xml_node.attributes["mode"]
    # Whether the gateway closed -> Happens when the gateway close event is processed
    @closed = false
    # Whether the gateway is already running (at least one branch signaled that it is runnign)
    @running = false
    @alternative_executed = false
    # Contains all branches by their condition -> list if multiple share condition, elements ordered in array as in xml top down
    @branch_nodes = {}
    @otherwise_node = nil

    # Setup all nodes
    xml_node.children.each do |alternative_branch_node|
      case node.qname.name
      when "alternative"
        let condition = node.find("string(@condition)")
        if @branch_nodes.key? condition
          @branch_nodes[condition] << node
        else
          @branch_nodes[condition] = [node]
        end
      when "otherwise"
        @otherwise_node = node
      end
      @branches << translate_from_xml(alternative_branch_node.children, self)
    end
  end

  def event(type, content)
    case type
    when "split"
      if @state_machine.can_split?
        @state_machine.split
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
    when "decide"
      if @state_machine.can_decide?
        @state_machine.decide
        let node = @branch_nodes[content["code"]].shift
        if @branch_nodes[content["code"]].empty?
          @branch_nodes.delete content["code"]
        end
        if content["condition"]
          # Instantiate alternative
          @branches << Branch.new(@process, node, self, :alternative, self)
          alternative_executed = true
        elsif @branch_nodes.empty?
          @branches << Branch.new(@process, @otherwise_node, :otheriwse, self)
        end
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
    when "join"
      if @state_machine.can_join?
        @state_machine.join
      else
        raise "ERROR: this #{type} event happens in wrong state: #{@state_machine.state}"
      end
    else
      raise "ERROR: Eventtype #{type} not possible for #{self.class}"
    end
  end

  def done?
    @closed
  end

  def signal_branch_running(branch)
    @started_branches << branch
    if !@running
      @running = true
      @parent_branch.signal_running self
    end
  end

  def signal_end_of_branch(branch)
    @finished_branches << branch
    # {{{
    # if @mode == "exclusive"
    #   if @chosen_branches.empty?
    #     @chosen_branches << {branch_id:@branches[branch_id]}
    #     @branches.each do |branch|
    #       unless branch.branch_id == branch_id
    #         @parent_process.signal_end_of_task(task_id, branch_id)
    #         @current_elements.delete(task_id)
    #       end
    #     end
    #   else
    #     @current_elements.delete(task_id)
    #     if @chosen_branches.values.first.branch_ended?
    #       @branch_ended= true
    #     end
    #     @parent_process.signal_end_of_task(task_id, branch_id)
    #   end
    # else
    #   # TODO: contemplate about how to know when inclusive gateway ends
    #   unless @chosen_branches.include?(branch_id)
    #     @chosen_branches << {branch_id:@branches[branch_id]}
    #   end
    #   if @chosen_branches[@active_node].branch_ended?
    #     @active_node +=1
    #   end
    #   @parent_process.signal_end_of_task(task_id, branch_id)
    #   @current_elements.delete(task_id)
    # end
    # }}}
  end

  # TODO: Execute this if the gateway join comes
  def check_for_correctness
    if !self.done?
      return false
    end
    # In a choice gateway all branches that execute have to finish!
    if @started_branches.length != @finished_branches.length
      return false
    end
    if @mode == "exclusive"
      if @finished_branches.length != 1
        return false
      end
    else # inclusive
      executed_otherwise = finished_branches.any? { |e| e.type == :otherwise }
      if executed_otherwise && @finished_branches.length != 1
        return false
      end
    end
    @branches.map { |branch| branch.check_for_correctness }.all?
  end
end

class Loop
  def initialize(xml_node, process, parent_branch)
    @process = process
    @parent_branch = parent_branch
    @branches = []
    @finished_branches = []
    @mode = xml_node.attributes["mode"]
    # Whether the gateway closed -> Happens when the gateway close event is processed
    @closed = false
    # Whether the gateway is already running (at least one branch signaled that it is runnign)
    @running = false
    @loop_body = xml_node.children
    @iteration = 0
    if @mode == "post_test"
      @branches << Branch.new(@process, @loop_body, self, :loop)
    end
  end

  def event(type, content)
    case type
    when "decide"
      if content["condition"]
        # Another iteration
        self.iteration += 1
        @branches << Branch.new(@process, @loop_body, self, :loop + self.iteration)
      else
        self.closed = true
        @parent_branch.signal_end
      end
    else
      raise "ERROR: Eventtype #{type} not possible for #{self.class}"
    end
  end

  def done?
    @closed
  end

  def signal_branch_running(branch)
    if !@running
      @running = true
      @parent_branch.signal_running self
    end
  end

  def signal_end_of_branch(branch)
    @finished_branches << Branch
  end

  # TODO: Execute this if the gateway join comes
  def check_for_correctness
    if !self.done?
      return false
    end
    # In a choice gateway all branches that execute have to finish!
    if @started_branches.length != @finished_branches.length
      return false
    end
    @branches.map { |branch| branch.check_for_correctness }.all?
  end
end

# Parent: Either the gateway that spawned a branch, or a branch that spawned a gateway or activity
def translate_from_xml(node, parent)
  case node.qname.name
  when "call"
    # TODO: Probably need to adapt this code here for different code types?
    with_scripts = false
    node.children.each do |child_node|
      if child_node.qname.name == "code"
        with_scripts = true
      end
    end
    if with_scripts
      ServiceScriptCall.new(node.attributes["id"], parent)
    else
      ServiceCall.new(node.attributes["id"], parent)
    end
  when "manipulate"
    ScriptCall(node.attributes["id"], parent)
  when "parallel"
    ParallelGateway.new(node, parent.process)
  when "parallel_branch"
    Branch.new(parent.process, node.children, :parallel_branch, parent)
  when "choose"
    DecisionGateway.new(node, parent.process, parent)
  else
    p "Ignoring unimplemented XML node case: #{node.qname.name}"
  end
end

def extract_id(event, content)
  case event[0]
  when "state"
    # State events are not related to any nodes
    return nil
  when "gateway"
    p "Cannot extract id from gateway yet"
    # TODO: Implement getting gateway id
  when "activity"
    case event[1]
    when "calling", "receiving", "done", "manipulating"
      content["activity"]
    end
  end
end

def handle_resource_utilization(content)
end

ruby_log_file = File.read("./ruby_log_complete_single_timeout.json")
ruby_log = JSON.parse(ruby_log_file).map { |k, v| [k.to_i, v] }.to_h
testfile = "./service_call.xml"
doc = XML::Smart.open(testfile)
doc.register_namespace "p", "http://cpee.org/ns/properties/2.0"
doc.register_namespace "d", "http://cpee.org/ns/description/1.0"
description = doc.find("p:testset/p:description/d:description")[0]
process_instance = ProcessInstance.new(description)
ruby_log.each do |_key, value|
  if value["channel"].include? "callback"
    # Ignore all callback events
    next
  end
  event = value["channel"].sub!(/event:\d\d:/, "")
  event = event.split("/", 2)
  content = value["message"]["content"]
  if event[1] == "resource_utilization"
    next # TODO: For now we do not handle resource util.
    #handle_resource_utilization content
  end
  id = extract_id(event, content)
  process_instance.process_event(event, id, content)
end

p process_instance.check_for_correctness
