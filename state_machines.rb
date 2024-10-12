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



serviceScriptTask = ServiceScriptCallMachine.new
scriptTask = ScriptCallMachine.new



def test_service_call_statemachine()
  serviceTask = ServiceCall.new
  puts "First state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
        Error: #{serviceTask.can_error?} \n
        Call: #{serviceTask.can_call?} \n
        Get Content: #{serviceTask.can_get_content?} \n
        Receive: #{serviceTask.can_receive?} \n
        End Callback: #{serviceTask.can_end_callback?} \n
        End Activity: #{serviceTask.can_end_activity?} \n"
  serviceTask.error
  puts "Current state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
  Error: #{serviceTask.can_error?} \n
  Call: #{serviceTask.can_call?} \n
  Get Content: #{serviceTask.can_get_content?} \n
  Receive: #{serviceTask.can_receive?} \n
  End Callback: #{serviceTask.can_end_callback?} \n
  End Activity: #{serviceTask.can_end_activity?} \n"
    
  serviceTask = ServiceCall.new 
  serviceTask.call
  puts "Current state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
        Error: #{serviceTask.can_error?} \n
        Call: #{serviceTask.can_call?} \n
        Get Content: #{serviceTask.can_get_content?} \n
        Receive: #{serviceTask.can_receive?} \n
        End Callback: #{serviceTask.can_end_callback?} \n
        End Activity: #{serviceTask.can_end_activity?} \n"
  
    
  serviceTask.get_content
  puts "Current state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
        Error: #{serviceTask.can_error?} \n
        Call: #{serviceTask.can_call?} \n
        Get Content: #{serviceTask.can_get_content?} \n
        Receive: #{serviceTask.can_receive?} \n
        End Callback: #{serviceTask.can_end_callback?} \n
        End Activity: #{serviceTask.can_end_activity?} \n"
    
  serviceTask.receive
  puts "Current state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
        Error: #{serviceTask.can_error?} \n
        Call: #{serviceTask.can_call?} \n
        Get Content: #{serviceTask.can_get_content?} \n
        Receive: #{serviceTask.can_receive?} \n
        End Callback: #{serviceTask.can_end_callback?} \n
        End Activity: #{serviceTask.can_end_activity?} \n"
    
  serviceTask.end_callback
  puts "Current state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
        Error: #{serviceTask.can_error?} \n
        Call: #{serviceTask.can_call?} \n
        Get Content: #{serviceTask.can_get_content?} \n
        Receive: #{serviceTask.can_receive?} \n
        End Callback: #{serviceTask.can_end_callback?} \n
        End Activity: #{serviceTask.can_end_activity?} \n"
    
  serviceTask.end_activity
  puts "Current state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
        Error: #{serviceTask.can_error?} \n
        Call: #{serviceTask.can_call?} \n
        Get Content: #{serviceTask.can_get_content?} \n
        Receive: #{serviceTask.can_receive?} \n
        End Callback: #{serviceTask.can_end_callback?} \n
        End Activity: #{serviceTask.can_end_activity?} \n"
end

def test_servicescriptcall_statemachine()
  serviceTask = ServiceScriptCall.new
  puts "First state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
        Error: #{serviceTask.can_error?} \n
        Call: #{serviceTask.can_call?} \n
        Get Content: #{serviceTask.can_get_content?} \n
        Receive: #{serviceTask.can_receive?} \n
        Change Dataelements: #{serviceTask.can_change_dataelements?} \n
        End Callback: #{serviceTask.can_end_callback?} \n
        Manipulate: #{serviceTask.can_manipulate?} \n
        End Activity: #{serviceTask.can_end_activity?} \n"
  serviceTask.error
  puts "Current state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
  Error: #{serviceTask.can_error?} \n
  Call: #{serviceTask.can_call?} \n
  Manipulate: #{serviceTask.can_manipulate?} \n
  Get Content: #{serviceTask.can_get_content?} \n
  Receive: #{serviceTask.can_receive?} \n
  Change Dataelements: #{serviceTask.can_change_dataelements?} \n
  End Callback: #{serviceTask.can_end_callback?} \n
  End Activity: #{serviceTask.can_end_activity?} \n"
  serviceTask = ServiceScriptCall.new
  serviceTask.call
  puts "Current state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
  Error: #{serviceTask.can_error?} \n
  Call: #{serviceTask.can_call?} \n
  Change Dataelements: #{serviceTask.can_change_dataelements?} \n
  Get Content: #{serviceTask.can_get_content?} \n
  Manipulate: #{serviceTask.can_manipulate?} \n
  Receive: #{serviceTask.can_receive?} \n
  End Callback: #{serviceTask.can_end_callback?} \n
  End Activity: #{serviceTask.can_end_activity?} \n"
  serviceTask.get_content
  puts "Current state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
  Error: #{serviceTask.can_error?} \n
  Call: #{serviceTask.can_call?} \n
  Get Content: #{serviceTask.can_get_content?} \n
  Manipulate: #{serviceTask.can_manipulate?} \n
  Receive: #{serviceTask.can_receive?} \n
  Change Dataelements: #{serviceTask.can_change_dataelements?} \n
  End Callback: #{serviceTask.can_end_callback?} \n
  End Activity: #{serviceTask.can_end_activity?} \n"
  serviceTask.receive
  puts "Current state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
  Error: #{serviceTask.can_error?} \n
  Call: #{serviceTask.can_call?} \n
  Get Content: #{serviceTask.can_get_content?} \n
  Receive: #{serviceTask.can_receive?} \n
  Manipulate: #{serviceTask.can_manipulate?} \n
  Change Dataelements: #{serviceTask.can_change_dataelements?} \n
  End Callback: #{serviceTask.can_end_callback?} \n
  End Activity: #{serviceTask.can_end_activity?} \n"
  serviceTask.end_callback
  puts "Current state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
  Error: #{serviceTask.can_error?} \n
  Call: #{serviceTask.can_call?} \n
  Manipulate: #{serviceTask.can_manipulate?} \n
  Get Content: #{serviceTask.can_get_content?} \n
  Change Dataelements: #{serviceTask.can_change_dataelements?} \n
  Receive: #{serviceTask.can_receive?} \n
  End Callback: #{serviceTask.can_end_callback?} \n
  End Activity: #{serviceTask.can_end_activity?} \n"
  serviceTask.manipulate
  puts "Current state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
  Error: #{serviceTask.can_error?} \n
  Call: #{serviceTask.can_call?} \n
  Manipulate: #{serviceTask.can_manipulate?} \n
  Get Content: #{serviceTask.can_get_content?} \n
  Change Dataelements: #{serviceTask.can_change_dataelements?} \n
  Receive: #{serviceTask.can_receive?} \n
  End Callback: #{serviceTask.can_end_callback?} \n
  End Activity: #{serviceTask.can_end_activity?} \n"
  serviceTask.error
  puts "Current state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
  Error: #{serviceTask.can_error?} \n
  Call: #{serviceTask.can_call?} \n
  Manipulate: #{serviceTask.can_manipulate?} \n
  Get Content: #{serviceTask.can_get_content?} \n
  Receive: #{serviceTask.can_receive?} \n
  End Callback: #{serviceTask.can_end_callback?} \n
  Change Dataelements: #{serviceTask.can_change_dataelements?} \n
  End Activity: #{serviceTask.can_end_activity?} \n"
  serviceTask = ServiceScriptCall.new
  serviceTask.state = "manipulated"
  serviceTask.change_dataelements
  puts "Current state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
  Error: #{serviceTask.can_error?} \n
  Call: #{serviceTask.can_call?} \n
  Manipulate: #{serviceTask.can_manipulate?} \n
  Get Content: #{serviceTask.can_get_content?} \n
  Receive: #{serviceTask.can_receive?} \n
  End Callback: #{serviceTask.can_end_callback?} \n
  Change Dataelements: #{serviceTask.can_change_dataelements?} \n
  End Activity: #{serviceTask.can_end_activity?} \n"
  serviceTask.end_activity
  puts "Current state: #{serviceTask.state}"
  puts "Possible transitions from #{serviceTask.state}: \n 
  Error: #{serviceTask.can_error?} \n
  Call: #{serviceTask.can_call?} \n
  Manipulate: #{serviceTask.can_manipulate?} \n
  Get Content: #{serviceTask.can_get_content?} \n
  Receive: #{serviceTask.can_receive?} \n
  Change Dataelements: #{serviceTask.can_change_dataelements?} \n
  End Callback: #{serviceTask.can_end_callback?} \n
  End Activity: #{serviceTask.can_end_activity?} \n"
 
end

#test_service_call_statemachine()
#test_servicescriptcall_statemachine()