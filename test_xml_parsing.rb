#!/usr/bin/ruby
require 'rubygems'
require "xml/smart"
#require_relative "test_process_model_structure"






testfile = "TestXMLs/paralleltest.xml"
doc = XML::Smart.open("/home/i17/Downloads/#{testfile}")
doc.register_namespace 'p', 'http://cpee.org/ns/properties/2.0'
doc.register_namespace 'd', 'http://cpee.org/ns/description/1.0'


# find description part of properties
nodes = doc.find("/p:testset/p:description/d:description/d:*")
active_tasks = []

def get_current_nodes(nodes)
    node = nodes.first
    
    case node.qname.name

    when "call"
      if node.children.include?("code")
        active_tasks << ServiceScriptCall.new(node.attributes["id"])
        nodes.shift
        nodes
      else
        active_tasks << ServiceCall.new(node.attributes["id"])
        nodes.shift
        nodes
    when "manipulate"
        active_tasks << ScriptCall.new(node.attributes["id"])
        nodes.shift
        nodes
    when "parallel"
        node.each do |child_node| get_current_nodes(child_node.children) end
    when "parallel_branch"
        get_current_nodes(node.children)



    when ""
    end
end




#nodes.each {|node| if node.qname.name == "parallel" then p node.children[1].children[0].qname.name end}