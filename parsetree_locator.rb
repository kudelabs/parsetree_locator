unless ARGV[0] && ARGV[1]
  puts %(Usage: 

  ruby parsetree_locator.rb <node_name> <file.rb>
  
  Examples:
  1. Find all instance variable assignments in 'massive_code_file.rb':
  
  ruby parsetree_locator.rb "iasgn" "massive_code_file.rb"
  
  2. Find and list all method calls in 'massive_code_file.rb':
  
  ruby parsetree_locator.rb "call" "massive_code_file.rb"
  
  3. Find and list all methods defined in "massive_code_file.rb":
  
  ruby parsetree_locator.rb "defn" "massive_code_file.rb"
  
  NOTE:
  - requires 'ruby_parser' gem;
  - works on Ruby 1.9.2, untested on other versions;
  - per 'ruby_parser' notes, "line numbers can be slightly off".
  )
  Process.exit
end

require 'ruby_parser'

class GenericParseTreeLocator
  attr_reader :node_type, :filename
  
  def initialize filename, node_type
    @filename = filename
    @code = IO.read filename
    @node_type = node_type
    
    @lines = @code.split("\n").collect(&:strip!)
    
    @ast = RubyParser.new.process @code, filename
    
    @poi = []   # positions of interest
    @poi_index = {}
    @curr_position = []
  end
  
  def register_poi(nodetype, name, linenr)
    @poi << [@curr_position.clone, nodetype, name, linenr]
    @poi_index[@curr_position.to_s] = [nodetype, name]
  end
  
  def process_ast_level sub_astree
    return if sub_astree.empty?

    case sub_astree[0]
      when :module, :class, :defn, node_type
        register_poi sub_astree[0], sub_astree[1], sub_astree.line
    end

    sub_astree.each_with_index do |sae, i|
      @curr_position.push i
      process_ast_level(sae) if sae.is_a?(RubyParser::Sexp)
      ex_i = @curr_position.pop
    end
  end
  
  def locate_nodes!
    process_ast_level @ast
  end
  
  NESTING_NODES = [:module, :class, :defn]
  def find_where_nested(position)
    result = []
    
    # try empty array first
    el = @poi_index["[]"]
    result << el if (el && NESTING_NODES.include?(el[0]))
    
    for ep in 0..position.size-2 do
      chunk = position[0..ep]
      el = @poi_index[chunk.to_s]
      if el
        eltype, elname = el
        result << el if NESTING_NODES.include?(eltype)
      end 
    end
    result
  end
  
  def get_code_line linenr
    @lines[linenr - 1]
  end
  
  def print_result
    iasgn_poi = @poi.select{|p| p[1] == node_type}.sort{|p1, p2| p1[3] <=> p2[3]}   # sort by line nr
    output_fstr = "%-7s | %-50s | %s"
    puts output_fstr % ["Line nr", "Module, class, method", "Code"]
    iasgn_poi.each do |ip|
      pos, nodetype, name, linenr = ip
      nested_in = find_where_nested pos
      infoline = ""
      nested_in.each_with_index do |nie, i|
        nt, nname = nie
        if nt == :defn
          infoline += "##{nname}"
        else
          infoline += ", " unless i == 0
          infoline += "#{nt} #{nname}"
        end
      end
      location_info = "#{linenr}:"
      infoline = output_fstr % [location_info, infoline , get_code_line(linenr)]
      puts infoline
    end
  end
end

ntype = ARGV[0].to_sym
fn = ARGV[1]

gptl = GenericParseTreeLocator.new(fn, ntype)
gptl.locate_nodes!

gptl.print_result
