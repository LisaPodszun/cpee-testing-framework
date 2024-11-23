#! /usr/bin/ruby
require 'rubygems'
require 'securerandom'
require_relative 'state_machines'


# TODO: handle specific error cases differently


class ServiceCall
  attr_reader :id
  def initialize(id, parent)
     @parent = parent
     @id = id
     @state_machine =  ServiceCallMachine.new
  end

  def event(type)
    case type
    when "calling"
      if state_machine.can_call?
         state_machine.call
      else
        raise "ERROR: this #{type} event happens in wrong state"
      end
    when "error"
      if state_machine.can_error?
         state_machine.error
      else
        raise "ERROR: this #{type} event happens in wrong state"
      end
    when "content"
      if state_machine.can_get_content?
         state_machine.get_content
      else
        raise "ERROR: this #{type} event happens in wrong state"
      end
    when "receiving"
      if state_machine.can_receive? 
         state_machine.receive
      else
        raise "ERROR: this #{type} event happens in wrong state"
      end  
    when "done"
      if state_machine.can_end?
         state_machine.end_activity
      else
         raise "ERROR: this #{type} event happens in wrong state"
      end
      if state_machine.done?
        @parent_process.signal_end(@id, @parent_process.branch_id)
      else
        raise "ERROR: state machine is not yet done to signal the end"
      end
    else
      raise "ERROR: Eventtype not possible for #{this.class}"
    end
  end

  def check_for_correctness
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
      if state_machine.can_call?
         state_machine.call
      else
        raise "ERROR: this #{type} event happens in wrong state"
      end
    when "error"
      if state_machine.can_error?
         state_machine.error
      else
        raise "ERROR: this #{type} event happens in wrong state"
      end
    when "content"
      if state_machine.can_get_content?
         state_machine.get_content
      else
        raise "ERROR: this #{type} event happens in wrong state"
      end
    when "receiving"
      if state_machine.can_receive? 
         state_machine.receive
      else
        raise "ERROR: this #{type} event happens in wrong state"
      end
    when "manipulating"
      if state_machine.can_manipulate?
         state_machine.manipulate
      else 
        raise "ERROR: this #{type} event happens in wrong state"
      end
    when "change"
      if state_machine.can_change_dataelements?
         state_machine.change_dataelements
      else 
        raise "ERROR: this #{type} event happens in wrong state"  
      end
    when "done"
      if state_machine.can_end?
         state_machine.end_activity
      else
        raise "ERROR: this #{type} event happens in wrong state"
      end
      if state_machine.done?
        @parent_process.signal_end(@id, @parent_process.branch_id)
      else
        raise "ERROR: state machine is not yet done to signal the end"
      end
    else
      "ERROR: Eventtype not possible for #{this.class}"
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
      if state_machine.can_manipulate?
         state_machine.manipulate
      else
        raise "ERROR: this #{type} event happens in wrong state"
      end
    when "error"
      if state_machine.can_error?
         state_machine.error
      else 
        raise "ERROR: this #{type} event happens in wrong state"
      end
    when "change"
      if state_machine.can_change_dataelements?
         state_machine.change_dataelements
         state_machine.end_activity
      else
        raise "ERROR: this #{type} event happens in wrong state"
      end
      if state_machine.done?
        @parent_process.signal_end(@id, @parent_process.branch_id)
      else
        raise "ERROR: state machine is not yet done to signal the end"
      end
    else
      "ERROR: Eventtype not possible for #{this.class}"
    end
  end

  def check_for_correctness
    self.activity_done? || @state_machine.ready?
  end

  def activity_done?
    @state_machine.done?
  end
end


# TODO: This should result in branches parallel_branch ndoes, allternatives, otherwise
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
      ServiceScriptCall(node.attributes["id"]) 
    else
      ServiceCall(node.attributes["id"])
    end
  when "manipulate"
    ScriptCall(node.attributes["id"])
  when "parallel"
    ParallelGateway(node, parent.process)
  when "parallel_branch"
    Branch(parent.process, node.children, :parallel_branch, parent)
  when "choose"
    DecisionGateway(node, parent.process, parent)
  else
    p "Ignoring unimplemented XML node case: #{node.qname.name}"
  end
end

class Process
  attr_accessor :finished

  def initialize(description)
    @description = description
    @active_activities = {}
    @active_gateways = {}
    @main_branch = 
    @process_ended = false
    @finished = false
  end
  
  def process_event(event, id, content = nil)
    if @active_activities.key?(id)
      @active_activities[id].event(event)
    elsif @active_gateways.key?(id)
      @active_gateways[id].event(event, content)
    else
      p "Cannot process event #{event} for id #{id}"
      # TODO handle error case
    end
  end

  def add_active_activity(activity_id, activity_node)
    if @active_activities.key? activity_id
      p "Key already contained!!!"
      # TODO: Handle error
    end
    @active_activities[id] = element
  end

  def remove_active_activity(activity_id)
    if !@active_activities.key? activity_id
      p "Key not contained!!!"
      # TODO: Handle error
    end
    @active_activities.delete element
  end

  # parallel, decision, loop
  def add_active_gateway(gid, node)
    @active_gateways[gid] << gateway
  end

  def remove_active_gateway(gid)
    if !@active_gateways.key? gid
      p "Key not contained!!!"
      # TODO: Handle error
    end
    @active_gateways.delete element
  end

  def process_ended?
    @process_ended
  end

  def check_for_correctness
    if !@main_branch.branch_ended?
      return false
    end
    @main_branch.check_for_correctness
  end
end

# Represents a thread of execution: Main Branch, branches for parallel and choice
class Branch
  
  # branch_nodes: all direct XML children of the branch
  def initialize(process, branch_nodes, gateway=nil, type)
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

  def event(type, content)
    case type
    when "calling"
      if state_machine.can_call?
         state_machine.call
      else
        raise "ERROR: this #{type} event happens in wrong state"
      end
    else
      raise "ERROR: Eventtype not possible for #{this.class}"
    end
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
    if @active_node != node
      p "Trying to remove non-active node: #{node}"
    end
    if node.class == (ScriptCall || ServiceScriptCall || ServiceCall)
      @process.remove_active_activity(node)
    else 
      @process.remove_active_gateway(node)
    end
    
    next_node_index = @active_node_index + 1
      
    if next_node_index < xml_node.length
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
    if next_node_index < xml_node.length
      next_element = translate_from_xml(xml_node[next_node_index], this)
      @structure << next_element
      if @structure[next_node_index].class == (ScriptCall || ServiceScriptCall || ServiceCall)
        @process.add_active_activity next_element.id, next_element
      else 
        @process.add_active_gateway next_element.gid, next_element
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
    if @active_node.nil
      return true
    else 
      @structure.map {|node| node.check_for_correctness}.all?
    end
  end
end

class ParallelGateway 
  def initialize(xml_node, process, parent_branch)
    @process = process
    @parent_branch = parent_branch
    @branches = []
    @started_branches = []
    @finished_branches = []
    @wait = xml_node.attributes["wait"]
    # Whether the gateway closed -> Happens when the gateway close event is processed
    @closed = false
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
    when "calling"
      if state_machine.can_call?
         state_machine.call
      else
        raise "ERROR: this #{type} event happens in wrong state"
      end
    else
      raise "ERROR: Eventtype not possible for #{this.class}"
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
    @branches.map {|branch| branch.check_for_correctness}.all?
  end
end

class DecisionGateway

  def initialize(xml_node, process, parent_branch)
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
      translate_from_xml()
      case node.qname.name
        when "alternative"
          let condition = node.find('string(@condition)')
          if @branch_nodes.key? condition 
            @branch_nodes[condition] << node
          else 
            @branch_nodes[condition] = [node]
          end
        when "otherwise"
          @otherwise_node = node
      end
      @branches << alternative_branch_node.children, self  
    end
  end

  def event(type, content)
    case type
    when "decide"
      let node = @branch_nodes[content["code"]].shift
      if @branch_nodes[content["code"]].empty?
        @branch_nodes.delete content["code"]
      end
      if content["condition"]
        # Instantiate alternative
        @branches << Branch(@process, node, self, :alternative, self)
        alternative_executed = true
      elsif @branch_nodes.empty? 
        @branches << Branch(@process, @otherwise_node, :otheriwse, self)
      end
    
    else
      raise "ERROR: Eventtype not possible for #{this.class}"
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
    if @mode == 'exclusive'
      if @finished_branches.length != 1
        return false
      end
    else # inclusive
      executed_otherwise = finished_branches.any? {|e| e.type == :otherwise}
      if executed_otherwise && @finished_branches.length != 1 
        return false
      end
    end
    @branches.map {|branch| branch.check_for_correctness}.all?
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
      @branches << Branch(@process, @loop_body, self, :loop)
    end

  def event(type, content)
    case type
    when "decide"
      if content["condition"]
        # Another iteration
        self.iteration += 1
        @branches << Branch(@process, @loop_body, self, :loop + self.iteration)
      else
        self.closed = true
        @parent_branch.signal_end
      end
    else
      raise "ERROR: Eventtype not possible for #{this.class}"
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
    @branches.map {|branch| branch.check_for_correctness}.all?
  end
end