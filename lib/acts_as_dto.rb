module ActsAsDto
  def self.included(base)
    base.extend ClassMethods
  end
  
  module ClassMethods
    
    VALID_DTO_OPTIONS = [:class_name, :method_name]
    
    def acts_as_dto(*args)      
      options = args.extract_options!      
      options.assert_valid_keys(VALID_DTO_OPTIONS)      

      field_function_map = args.inject(Hash.new) { |m,arg| arg.is_a?(Array) ? m[arg[0]] = arg[1] : m[arg] = arg; m }
      
      dto_class_name = options.has_key?(:class_name) ? options[:class_name] : self.to_s + "DataTransferObject"
      dto_method_name = options.has_key?(:method_name) ? options[:method_name] : "dto"
      Object.module_eval(<<-EVAL, __FILE__, __LINE__)     
        class #{dto_class_name}
          include ActsAsDto::Dto
          FIELD_MAP = { #{field_function_map.map{ |field,func| ":#{field} => :#{func}" }.join(",") } }
          attr_accessor *(FIELD_MAP.keys)

          def initialize(obj)
            
            FIELD_MAP.each do |field,func|
              instance_variable_set("@" + field.to_s, obj.send(func)) rescue nil
            end
          end                    
        end
        
      EVAL

      module_eval(<<-EVAL, __FILE__, __LINE__)
        def #{dto_method_name}
          #{dto_class_name}.new(self)
        end      
      EVAL
      
    end
        
  end
  
  module Dto
    def to_xml(options = {})
      options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      xml.tag!(self.class.name.underscore.dasherize.gsub('/', '_')) do
        self.instance_variables.each do |varname|
          var = self.instance_variable_get(varname)
          if var.is_a?(ActsAsDto::Dto)
            xml << var.to_xml(:skip_instruct => true, :root => var.class.name.pluralize.underscore.dasherize.gsub('/', '_'), :skip_types => true)
          elsif var.is_a?(Array)
            xml << var.to_xml(:skip_instruct => true, :root => var.first.class.name.pluralize.underscore.dasherize.gsub('/', '_'), :skip_types => true) 
          else
            xml.tag!(varname[1..-1],var)
          end
        end
      end
    end    
  end
end