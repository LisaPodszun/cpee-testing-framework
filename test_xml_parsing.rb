#!/usr/bin/ruby
require 'rubygems'
require "xml/smart"
require_relative "test_process_model_structure"


def get_current_nodes(nodes, active_tasks)
    
end




testfile = "TestXMLs/paralleltest.xml"
doc = XML::Smart.open("/home/i17/Downloads/#{testfile}")
doc.register_namespace 'p', 'http://cpee.org/ns/properties/2.0'
doc.register_namespace 'd', 'http://cpee.org/ns/description/1.0'


# find description part of properties
nodes = doc.find("/p:testset/p:description/d:description/d:*")
active_tasks = []


# iterate over model

p nodes[0].attributes["id"]
