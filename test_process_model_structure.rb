#! /usr/bin/ruby
require 'rubygems'
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
    def ended?
      @state_machine.done?
    end
end


class Process
  attr_accessor :subelements
  @@current_element
  @index = 0
  @subelements = 0
  def initialize(process)
    @parent_process = process
    @structure = []
  end
  def add_element(element)
    @structure << element
  end
  def add_subelement(element)
    if @parent_process.class == Process
      @parent_process.subelements += 1
    else
      @parent_process.subelements += 1
      @parent_process.add_subelement(element)
  end
  def next
    if subelements == 0
      @index += 1
      @@current_element = @structure.shift
    else 
      @@current_element = @structure.at(@index).next 
    end
  end
end

class ParallelGateway < Process
  attr_accessor :wait_on_branches

  def initialize(process, wait, cancel)
    @process = process
    @wait = wait
    if wait == -1
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
end

class ParallelBranch < Process
  attr_reader :parallel_gateway

  def initialize(parallel_gateway)
    @parallel_gateway = parallel_gateway
  end
  def signal_end
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

  def next
    if @parallel_gateway.wait == -1
      if @structure.length > 0
        if subelements == 0
          @index += 1
          @@current_element = @structure.shift
        else 
          @@current_element = @structure.at(@index).next 
        end
      else
        while !@@current_element.ended?
        end
        signal_end  
    else
      if @parallel_gateway.cancel == "after_first"
        if subelements == 0 && @index == 0
          @index += 1
          @@current_element = @structure.shift
          
          
    end
  end
end

class DecisionGateway < Process

  def initialize(process, mode)
    @process = process
    @mode = mode
    @structure = []
  end
end

class Alternative < Process
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

