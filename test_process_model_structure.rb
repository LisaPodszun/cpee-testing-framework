#! /usr/bin/ruby
require 'rubygems'
require 'securerandom'
require_relative 'state_machines'


# TODO: handle specific error cases differently
class ServiceCall
  attr_reader :id
  def initialize(id, parent_process)
     @parent_process = parent_process
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
end

class ServiceScriptCall
  attr_reader :id
  def initialize(id, parent_process)
    @parent_process = parent_process
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
end

class ScriptCall
  attr_reader :id
  def initialize(id, parent_process)
    @parent_process = parent_process
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
end

def translate_from_xml(node, parent_process)

  case node.qname.name
  when "call"
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
      ParallelGateway(node)
  when "parallel_branch"
      ParallelBranch(node)
  when "choose"
    # todo 
  when "alternative"
    # todo
  when "otherwise"
    # todo
  else
    # todo
  end
end


class Branch
  attr_accessor :current_elements, :structure, :index
  attr_reader :branch_id

  def initialize(xml_node, parent_process=nil)
    @parent_process = parent_process
    @branch_id = SecureRandom.hex(5)
    @xml_node = xml_node
    @current_elements = {}
    @structure = []
    @process_ended = false
    @index = 0
  end
  
  def process_log(type, id)
    if @current_elements.key?(id)
       @current_elements[id].event(type)
    else
      # TODO handle error case
    end
  end

  def signal_end_of_task(task_id, branch_id)
    unless @parent_process.nil?
      @parent_process.signal_end_of_task(task_id, branch_id)
      @current_elements.delete(task_id)
    else
      @current_elements.delete(task_id)
      next_elements
    end
  end

  def process_ended?
    @process_ended
  end

  def next_elements
    if @index < xml_node.length
      if @structure[@index].process_ended?
        @structure << translate_from_xml(xml_node[@index], this)
        if @structure[@index].class == (ScriptCall || ServiceScriptCall || ServiceCall)
          @current_elements.store(@structure[@index].id, @structure[@index])
        else 
          @current_elements << @structure[@index].next_elements
        end
        @index += 1
      end
      @current_elements
    else 
      process_ended= true
    end
  end
end

class ParallelGateway 
  attr_accessor :wait, :current_elements, :process_ended

  def initialize(xml_node, parent_process)
    @wait = xml_node.attributes["wait"]
    @parent_process = parent_process
    @current_elements = {}
    @executing_branches = {}
    @finished_branches = {}
    @branches = {}
    @process_ended = false
    xml_node.children.each do |parallel_branch_node| 
      @branches << translate_from_xml(parallel_branch_node.children, this)  
    end
    unless @wait == "-1"
      @wait_on_branches = @wait
      @cancel = xml_node.attributes["cancel"]
    end
  end

  def process_ended?
    @process_ended
  end
  
  def next_elements
    @branches.each do |branch|
      unless branch.process_ended?   
        @current_elements << branch.next_elements
      end
    end
    @current_elements
  end
  
  def signal_end_of_task(task_id, branch_id)
    unless @wait == ("-1" || "0") 
      if @cancel == "after_first"
        # there are still parallel branches to wait on
        if @wait_on_branches - 1 > 0
          unless @executing_branches.include?(branch_id)
            @wait_on_branches -= 1
            @executing_branches << {branch_id:@branches[branch_id]}
          end
        else
        # last branch to wait on has finished the first task
          unless @executing_branches.include?(branch_id)
            @wait_on_branches -= 1
            @executing_branches << {branch_id:@branches[branch_id]}
            @branches.keys.each do |branch|
              unless @executing_branches.include?(branch)
                branch.process_ended= true
              end 
            end
          end
        end
      else
         # there are still parallel branches to wait on
        if @wait_on_branches - 1 > 0
          if @branches[branch_id].process_ended?
            @wait_on_branches -= 1
            @finished_branches << {branch_id:@branches[branch_id]}
          end
        else
          if @branches[branch_id].process_ended?
            @wait_on_branches -= 1
            @finished_branches << {branch_id:@branches[branch_id]}
            process_ended= true
          end  
        end
      end
    else
      # wait for all branches and mark all finished branches
      if @branches[branch_id].process_ended?
        @finished_branches << {branch_id:@branches[branch_id]}
        if @finished_branches == @branches
          process_ended= true
        end
      end
    end
    # update finished tasks
    @current_elements.delete(task_id)
    @parent_process.signal_end_of_task(task_id, branch_id)
  end
end

class ParallelBranch < Branch
  attr_reader :parallel_gateway, :cancel
  def initialize(xml_node, parallel_gateway)
    @parent_process = parallel_gateway
    
  end
end


class Loop
end



class DecisionGateway

  def initialize(xml_node, parent_process)
    @parent_process = parent_process
    @mode = xml_node.attributes["mode"]
    @current_elements = {}
    @branches = {}
    @chosen_branches = {}
    @process_ended = false
    xml_node.children.each do |alternative_branch_node| 
      @branches << translate_from_xml(alternative_branch_node.children, this)  
    end
  end

  def process_ended?
    @process_ended
  end

  def next_elements
      if @mode == "exclusive"
        if @chosen_branches.empty?
          branches.each do |branch| 
            current_elements << branch.next_elements 
          end
        else   
          current_elements << @chosen_branches.values.first.next_elements
        end
      else
          # TODO: test inclusive mode of CPEE
      end
    @current_elements
  end

  def signal_end_of_task(task_id, branch_id)
      if @mode == "exclusive"
        if @chosen_branches.empty?
          @chosen_branches << {branch_id:@branches[branch_id]}
        else
          
      else
      end
  end
end

class Alternative < Branch
  attr_reader :decision_gateway

  def initialize(xml_node, decision_gateway)
    @parent_process = decision_gateway
    @condition = xml_node.attributes["condition"]
  end

  def signal_end
    @decision_gateway
  end
end

