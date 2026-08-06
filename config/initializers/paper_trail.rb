Rails.application.config.to_prepare do
  require "paper_trail/events/destroy"

  PaperTrail::Events::Destroy.class_eval do
    private

    def recordable_object_changes(_changes)
      nil
    end
  end
end
