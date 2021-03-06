[Account, Campaign, Contact, Lead, Opportunity, Task].each do |model|

  controller = (model.name.pluralize + 'Controller').constantize
  controller.class_eval do

    skip_before_filter :require_user, :only => :meta_search
    before_filter :require_application, :only => :meta_search
    skip_load_and_authorize_resource :only => :meta_search

    def meta_search

      alias_id_hash = {}
      if params[:search][:id_in]
        # Sanitizes params search ids, replaces deleted / merged object ids
        # with current ids.
        alias_id_hash = ContactAlias.ids_with_alias(params[:search][:id_in])
        params[:search][:id_in] = alias_id_hash.values.uniq
      end

      # Find all records that match our sanitized id set.
      if params[:search][:text_search]
        @search = klass.text_search(params[:search][:text_search])
      else
        @search = klass.search(params[:search]).result(:distinct => true)
      end
      @only = params[:only] || [:id, :name]
      @limit = params[:limit] || 10

      @search = @search.all(:include => params[:include], :limit => @limit)

      if params[:search][:id_in]
        @results = []
        # Iterate through search ids and the current asset id (for merged assets).
        alias_id_hash.each do |search_id, current_id|
          # If the search results contain the search id, add to results.
          if record = @search.detect{|record| record.id == search_id.to_i }
            r = record.dup
            r.id = search_id
            @results << r
          # Else, if the search results don't contain the search id,
          # but the search results do contain the current id, change the current
          # id back to the old id and add to results.
          elsif record = @search.detect{|record| record.id == current_id.to_i }
            record_with_old_id = record.dup
            record_with_old_id.id = search_id
            @results << record_with_old_id
          # Finally, if no record exists then object has been destroyed, not merged
          # so return a new 'deleted' object.
          else
            deleted_params = case klass.name
              when 'Account', 'Campaign', 'Opportunity', 'Task'
                {:name => "[Deleted #{klass.name}]"}
              when 'Contact', 'Lead'
                {:first_name => "[Deleted", :last_name => "#{klass.name}]"}
              else
                {}
              end
            obj = klass.new(deleted_params)
            obj.id = search_id
            @results << obj
          end
        end
      else
        # Else, if we are just searching for a single record by id
        @results = @search

        # If we are using the crm_merge plugin, we also need to duplicate a returned
        # contact into a list including ancestors, in case the external application
        # contains an entry with a merged id.
        # (only if we are searching for a specific ID, though)
        if defined?(ContactAlias) and params[:search][:id_equals] and @results.any?
          contact = @results.first.dup
          ContactAlias.find_all_by_contact_id(contact.id).each do |ancestor|
            contact.id = ancestor.destroyed_contact_id
            @results << contact
          end
        end
      end

      respond_to do |format|
        format.json { render :json => @results.to_json(:only => [false], :methods => @only) }
        format.xml  { render :xml => @results.to_xml(:only => [false], :methods => @only) }
      end
    end

    private

    #----------------------------------------------------------------------------
    def current_application_session
      @current_application_session ||= ApplicationSession.find
    end

    #----------------------------------------------------------------------------
    def require_application
      unless current_application_session
        redirect_to login_url
        false
      end
    end

  end
end
