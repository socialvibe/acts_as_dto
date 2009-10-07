module ActsAsDto
  def self.included(base)
    base.extend ClassMethods
  end
  
  module ClassMethods
    
    VALID_DTO_OPTIONS = [:class_name, :method_name]
    
    def acts_as_dto(*args)      
      options = args.extract_options!      
      options.assert_valid_keys(VALID_DTO_OPTIONS)      
      attributes_to_define = args

      module_eval(<<-EVAL, __FILE__, __LINE__)     
        dto_class_name = #{options.has_key?(:class_name) ? "\"#{options[:class_name]}\"" : "nil"} || self.to_s + "DataTransferObject"
        dto_method_name = #{options.has_key?(:method_name) ? "\"#{options[:method_name]}\"" : "nil"} || "dto"
                       
        Object::const_set(dto_class_name.intern, Class::new do
          include Dto
          FIELDS = [#{attributes_to_define.map { |d| ":#{d}"}.join(",")}]
          attr_accessor *FIELDS

          def initialize(obj)
            FIELDS.each do |attribute|
              instance_variable_set("@" + attribute.to_s, obj.send(attribute)) rescue nil
            end
          end          
          
        end)
        
        create_dto_method(dto_class_name,dto_method_name)
      EVAL
      
    end
    
    private
    def create_dto_method(class_name,method_name)
      Rails.logger.info "Creating method #{method_name} for class #{class_name}"
      module_eval "
        def #{method_name}
          #{class_name}.new(self)
        end"
    end
  end
  
  module Dto
    def to_xml(options = {})
      options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      xml.tag!(self.class.name.underscore.dasherize) do
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
