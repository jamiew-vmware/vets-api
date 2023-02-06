# frozen_string_literal: true

class MessageDetailsSerializer < MessagesSerializer
  attribute :thread_id
  attribute :folder_id
  attribute :message_body
  attribute :draft_date
  attribute :to_date
  attribute :has_attachments
end
