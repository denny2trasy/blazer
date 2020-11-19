module Blazer
  class Query < Record
    attr_accessor :editor

    belongs_to :creator, optional: true, class_name: Blazer.user_class.to_s if Blazer.user_class
    has_many :checks, dependent: :destroy
    has_many :dashboard_queries, dependent: :destroy
    has_many :dashboards, through: :dashboard_queries
    has_many :audits
    has_many :versions, as: :versionable

    validates :statement, presence: true

    scope :active, -> { column_names.include?("status") ? where(status: "active") : all }
    scope :named, -> { where("blazer_queries.name <> ''") }

    after_save :save_version, if: -> { Blazer.versions? }

    def to_param
      [id, name].compact.join("-").gsub("'", "").parameterize
    end

    def friendly_name
      name.to_s.sub(/\A[#\*]/, "").gsub(/\[.+\]/, "").strip
    end

    def viewable?(user)
      if Blazer.query_viewable
        Blazer.query_viewable.call(self, user)
      else
        true
      end
    end

    def editable?(user)
      editable = !persisted? || (name.present? && name.first != "*" && name.first != "#") || user == try(:creator)
      editable &&= viewable?(user)
      editable &&= Blazer.query_editable.call(self, user) if Blazer.query_editable
      editable
    end

    def variables
      Blazer.extract_vars(statement)
    end

    def save_version
      version_changes = previous_changes.slice("name", "description", "statement", "data_source")
      if version_changes.any?
        versions.create!(
          user: editor,
          version_changes: version_changes,
          created_at: updated_at
        )
      end
    end
  end
end
