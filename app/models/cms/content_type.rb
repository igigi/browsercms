module Cms
  class ContentType < ActiveRecord::Base

    attr_accessor :group_name
    belongs_to :content_type_group, :class_name => 'Cms::ContentTypeGroup'
    validates_presence_of :content_type_group
    before_validation :set_content_type_group

    DEFAULT_CONTENT_TYPE_NAME = 'Cms::HtmlBlock'

    class << self
      def named(name)
        where(["#{ContentType.table_name}.name = ?", name])
      end

      def connectable
        available.select {|content_type| content_type.connectable? }
      end

      # Return all content types, grouped by module.
      #
      # @return [Hash<Symbol, Cms::ContentType]
      def available_by_module
        modules = {}
        available.each do |content_type|

          modules[content_type.module_name] = [] unless modules[content_type.module_name]
          modules[content_type.module_name] << content_type
        end
        modules
      end
      # Returns a list of all ContentTypes in the system. Content Types can opt out of this list by specifying:
      #
      #   class MyWidget < ActiveRecord::Base
      #     acts_as_content content_module: false
      #   end
      #
      # Ignores the database to just look at classes, then returns a 'new' ContentType to match.
      #
      # @return [Array<Cms::ContentType] An alphabetical list of content types.
      def available
        subclasses = ObjectSpace.each_object(::Class).select do |klass|
          klass < Cms::Concerns::HasContentType::InstanceMethods
        end
        subclasses << Cms::Portlet
        subclasses.uniq! {|k| k.name} # filter duplicate classes
        subclasses.map do |klass|
          unless klass < Cms::Portlet
            Cms::ContentType.new(name: klass.name)
          end
        end.compact.sort { |a, b| a.name <=> b.name }
      end

      def list
        all.map { |f| f.name.underscore.to_sym }
      end

      # Returns all content types besides the default.
      #
      # @return [Array<Cms::ContentType]
      def other_connectables()
        available.select { |content_type| content_type.name != DEFAULT_CONTENT_TYPE_NAME }
      end

      # Returns the default content type that is most frequently added to pages.
      def default()
        Cms::ContentType.new(name: DEFAULT_CONTENT_TYPE_NAME)
      end
    end


    # Given a 'key' like 'html_blocks' or 'portlet'. Looks first for a class in the Cms:: namespace, then again without it.
    # Raises exception if nothing was found.
    def self.find_by_key(key)
      class_name = key.tableize.classify
      content_type = where(["name like ?", "%#{class_name}"]).first
      if content_type.nil?
        if class_name.constantize.ancestors.include?(Cms::Portlet)
          content_type = Cms::ContentType.new(:name => class_name)
          content_type.content_type_group = Cms::ContentTypeGroup.find_by_name('Core')
          content_type.freeze
          content_type
        else
          raise "Not a Portlet"
        end
      else
        content_type
      end
    rescue Exception
      if class_name.starts_with? "Cms::"
        return self.find_by_key(class_name.gsub(/Cms::/, ""))
      end
      raise "Couldn't find ContentType of class '#{class_name}'"
    end


    # Return the name of the module this content type should be grouped in. In most cases, content blocks will be
    # configured to specify this.
    # @return [Symbol]
    def module_name
      model_class.content_module
    end

    # Returns URL friendly 'key' which is used to identify this
    def key
      model_class_form_name
    end

    # Returns the partial used to render the form fields for a given block.
    def form
      f = model_class.respond_to?(:form) ? model_class.form : "#{name.underscore.pluralize}/form"
      if main_app_model?
        f = "cms/#{f}"
      end
      f
    end

    def display_name
      model_class.respond_to?(:display_name) ? model_class.display_name : Cms::Behaviors::Connecting.default_naming_for(model_class)
    end

    def display_name_plural
      model_class.respond_to?(:display_name_plural) ? model_class.display_name_plural : display_name.pluralize
    end

    def model_class
      name.constantize
    end

    # @deprecated Should be removed eventually
    def route_name
      if model_class.name.starts_with?("Cms")
        model_class_form_name
      else
        "main_app.cms_#{model_class_form_name}"
      end
    end

    include EngineHelper

    def target_class
      model_class
    end

    def path_subject
      model_class
    end

    # Determines if the content can be connected to other pages.
    def connectable?
      model_class.connectable?
    end

    # Cms::HtmlBlock -> html_block
    # ThingBlock -> thing_block
    def model_class_form_name
      model_class.model_name.element
    end

    # Allows models to show additional columns when being shown in a list.
    def columns_for_index
      if model_class.respond_to?(:columns_for_index)
        model_class.columns_for_index.map do |column|
          column.respond_to?(:humanize) ? {:label => column.humanize, :method => column} : column
        end
      else
        [{:label => "Name", :method => :name, :order => "name"},
         {:label => "Updated On", :method => :updated_on_string, :order => "updated_at"}]
      end
    end

    # Used in ERB for pathing
    def content_block_type
      name.demodulize.pluralize.underscore
    end

    # This is used for situations where you want different to use a type for the list page
    # This is true for portlets, where you don't want to list all portlets of a given type,
    # You want to list all portlets
    def content_block_type_for_list
      if model_class.respond_to?(:content_block_type_for_list)
        model_class.content_block_type_for_list
      else
        content_block_type
      end
    end

    def set_content_type_group
      if group_name
        group = Cms::ContentTypeGroup.where(:name => group_name).first
        self.content_type_group = group || build_content_type_group(:name => group_name)
      end
    end

  end
end