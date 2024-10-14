#! /usr/bin/ruby
require 'rubygems'
require 'securerandom'
require_relative 'state_machines'

class ServiceCall
  def initialize(id)
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
    when "error"
      if state_machine.can_error?
         state_machine.error
      else
        raise "ERROR: this #{type} event happens in wrong state"
    when "content"
      if state_machine.can_get_content?
         state_machine.get_content
      else
        raise "ERROR: this #{type} event happens in wrong state"
    when "receiving"
      if state_machine.can_receive? 
         state_machine.receive
      else
        raise "ERROR: this #{type} event happens in wrong state"  
    when "done"
      if state_machine.can_end?
         state_machine.end_activity
      else
        raise "ERROR: this #{type} event happens in wrong state"
    else
      raise "ERROR: Eventtype not possible for #{this.class}"
    end
  def ended?
    @state_machine.done?
  end 
end

class ServiceScriptCall
  def initialize(id)
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
    when "error"
      if state_machine.can_error?
         state_machine.error
      else
        raise "ERROR: this #{type} event happens in wrong state"
    when "content"
      if state_machine.can_get_content?
         state_machine.get_content
      else
        raise "ERROR: this #{type} event happens in wrong state"
    when "receiving"
      if state_machine.can_receive? 
         state_machine.receive
      else
        raise "ERROR: this #{type} event happens in wrong state"
    when "manipulating"
      if state_machine.can_manipulate?
         state_machine.manipulate
      else 
        raise "ERROR: this #{type} event happens in wrong state"
    when "change"
      if state_machine.can_change_dataelements?
         state_machine.change_dataelements
      else 
        raise "ERROR: this #{type} event happens in wrong state"  
    when "done"
      if state_machine.can_end?
         state_machine.end_activity
      else
        raise "ERROR: this #{type} event happens in wrong state"
    else
      "ERROR: Eventtype not possible for #{this.class}"
    end
    def ended?
      @state_machine.done?
    end 
end

class ScriptCall
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
    when "error"
      if state_machine.can_error?
         state_machine.error
      else 
        raise "ERROR: this #{type} event happens in wrong state"
    when "change"
      if state_machine.can_change_dataelements?
         state_machine.change_dataelements
         state_machine.end_activity
      else
        raise "ERROR: this #{type} event happens in wrong state"
    else
      "ERROR: Eventtype not possible for #{this.class}"
    end
end


class Branch
  attr_accessor :subelements
  @current_element
  @subelements = 0
  def initialize(process)
    @parent_process = process
    @branch_id = SecureRandom.hex(5)
    @structure = []
  end
  def add_element(element)
    @structure << element
  end
  def next_element
    if subelements == 0
      @current_element = @structure.shift
      if @current_element.class == (ParallelGateway || DecisionGateway)
        @subelements += 1
      end
    else 
      @current_element = @current_element.next_element
    end
  end
end

class ParallelGateway 
  attr_accessor :wait_on_branches :current_elements

  def initialize(wait, cancel)
    @current_elements = []
    @wait = wait
    if @wait == -1
      @wait_on_branches = 0
    else
      @wait_on_branches = wait
      @cancel = cancel
  end

  def add_element(parallel_branch)
    @structure << parallel_branch
    if @wait < 0
      @wait_on_branches += 1
  end

  def next_element
    @structure.each do |element|
      @current_elements << element.next_element
    end
  end

  def signal_end(branch)

    if @parallel_gateway.wait == -1 && @parallel_gateway.cancel == "after_last"
       @parallel_gateway.wait_on_branches = @parallel_gateway.wait_on_branches-1
    elsif @parallel_gateway.wait == -1 && @parallel_gateway.cancel == "after_first"
      # TODO What is this case?
    elsif @parallel_gateway.wait != -1 && @parallel_gateway.cancel == "after_last"
       @parallel_gateway.wait_on_branches = @parallel_gateway.wait_on_branches-1
    else
       @parallel_gateway.wait_on_branches = 0
    end 
  end
  
end

class ParallelBranch < Branch
  attr_reader :parallel_gateway

  def initialize(parallel_gateway, cancel)
    @parallel_gateway = parallel_gateway
    @cancel = cancel
  end

  def is_done(this)
    @parallel_gateway.signal_end_of(this)
  end
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

