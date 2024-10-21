require 'rubygems'
require 'state_machines'


class ServiceCallMachine
  state_machine :state, initial: :ready do
    event :call do 
      transition ready: :called
    end
    event :error do
      transition ready: :got_error
    end
    event :get_content do
      transition called: :got_content
    end
    event :receive do
      transition got_content: :received
    end
    event :end_activity do
      transition received: :done
    end
  end
end

class ServiceScriptCallMachine
    state_machine :state, initial: :ready do
    event :call do
      transition ready: :called
    end
    event :error do
      transition %i[ready manipulated] => :got_error
    end
    event :get_content do
      transition called: :got_content
    end
    event :receive do
      transition got_content: :received
    end
    event :manipulate do
      transition received: :manipulated
    end 
    event :change_dataelements do
      transition manipulated: :dataelements_changed
    end
    event :end_activity do
      transition %i[dataelements_changed received manipulated] => :done
    end
  end
end

class ScriptCallMachine
  state_machine :state, initial: :ready do
    event :manipulate do
      transition ready: :manipulated
    end
    event :error do
      transition manipulated: :got_error
    end
    event :change_dataelements do
      transition manipulated: :dataelements_changed
    end
    event :end_activity do
      transition %i[dataelements_changed manipulated] => :done
    end
  end
end

class DecisionGatewayMachine
  state_machine :state, initial: :ready do
    event :split do 
      transition ready: :gateway_split
    end
    event :decide do 
      transition %i[gateway_split chosen_branch] => :chosen_branch
    end
  end
end

class ParallelGatewayMachine
  state_machine :state, initial: :ready do
    event :split do 
      transition ready: :gateway_split
    end
    event :join do 
      transition gateway_split: :parallel_done
    end
  end
end
