#! /usr/bin/ruby
require 'rubygems'
require 'securerandom'
require_relative 'state_machines'

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
        @parent_process.signal_end(@id)
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
        @parent_process.signal_end(@id)
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
        @parent_process.signal_end(@id)
      else
        raise "ERROR: state machine is not yet done to signal the end"
      end
    else
      "ERROR: Eventtype not possible for #{this.class}"
    end
  end
end

def translate_from_xml(node)

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
  when "choice"
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
  attr_accessor :subelements
  @subelements = 0
  def initialize(xml_node, parent_process)
    @parent_process = parent_process
    @branch_id = SecureRandom.hex(5)
    @xml_node = xml_node
    @current_elements = {}
    @structure = []
    @index = 0
  end
  
  def process_log(type, id)
    if @current_elements.key?(id)
       @current_elements[id].event(type)
    else
      
  end

  def signal_end(id)
    unless @parent_process.nil?
      @parent_process.signal_end(id)
      @current_elements.delete(id)
    else
      @current_elements.delete(id)
      next_elements
  end


  def next_elements
      @structure << translate_from_xml(xml_node[@index], this)
      if @structure[@index].class == (ScriptCall || ServiceScriptCall || ServiceCall)
         @current_elements.store(@structure[@index].id,@structure[@index])
      else 
         @current_elements << @structure[@index].next_elements
      end
      @index += 1
  end
end

class ParallelGateway 
  attr_accessor :wait_on_branches, :current_elements

  def initialize(xml_node)
    @executing_branches = []
    @current_elements = []
    @wait = wait
    if @wait == -1
      @wait_on_branches = 0
    else
      @wait_on_branches = wait
      @cancel = cancel
    end
  end

  def add_element(parallel_branch)
    @structure << parallel_branch
    if @wait < 0
      @wait_on_branches += 1
    end
  end

  def next_element(branch)
    @current_elements << @structure.at(@structure.index(branch)).next_element
  end

  def update_current_elements(element)
    @current_elements.delete(element)
    next_element
  end


  def cancel_other_branches(branch)
    if @wait_on_branches - 1 > 0
      @wait_on_branches -= 1
      @executing_branches << branch
    else
      @executing_branches << branch
      @structure.each do |branch|
        if !executing_branches.include? branch.branch_id
          @structure.delete(branch)
        end
      end
    end
  end

  def signal_end(branch)
         
  end
end

class ParallelBranch < Branch
  attr_reader :parallel_gateway, :cancel

  def initialize(xml_node,parallel_gateway)
    @parallel_gateway = parallel_gateway
    @cancel = cancel
  end
  def task_done
    @parallel_gateway.update_current_elements(@current_element,)
  end
  def is_first
    @parallel_gateway.cancel_other_branches(@branch_id)
  end

  def is_done
    @parallel_gateway.signal_end(@branch_id)
  end
end



class Loop
end


class DecisionGateway

  def initialize(process, mode)
    @process = process
    @mode = mode
    @structure = []
  end
end

class Alternative < Branch
  attr_reader :decision_gateway

  def initialize(decision_gateway, condition)
    @decision_gateway = decision_gateway
    @condition = condition
    @structure = []
  end

  def signal_end
    @decision_gateway
  end
end

