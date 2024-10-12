#!/usr/bin/ruby
require 'rubygems'
require "xml/smart"
require "./test_state_machine"




class Parallel
  def initialize
    @wait_for_branches
    @cancel
  end
end


class ParallelBranch
  def initialize

  end
end


class Choice
  def initialize
    @mode
  end
end


class Alternative
  def initialize
    @condition
  end
end

class ServiceCall
  def initialize
      
  end
end

class Manipulate
  def initialize
  end
end








testfile = "TestXMLs/twoparallel.xml"
doc = XML::Smart.open("/home/i17/Downloads/#{testfile}")
doc.register_namespace 'p', 'http://cpee.org/ns/properties/2.0'
doc.register_namespace 'd', 'http://cpee.org/ns/description/1.0'



nodes = doc.find("/p:testset/p:description/d:description/d:*")


current_possible_tasks = []




def get_current_nodes(node)
  
  case node.qname.name  
    when "call"
      p "case call"
      return node
    when "manipulate"
      p "case manipulate"
      return node
    when "parallel"
      p "case parallel"
      node.children
    when "parallel_branch"
      p "case parallel_branch"
      return node.children[0]
    when "choose"
      p "case choose"
      puts ""
    when "alternative"

    else
      puts "else path"
  end
end 

p nodes[1].attributes.first.qname.name

#nodes.each {|node| if node.qname.name == "parallel" then p node.children[1].children[0].qname.name end}