# Run under CRuby to verify the shared runtime's create/find/block behavior.
require_relative '../../tmp/roundhouse/toolchain-final-20261002/runtime/ruby/active_record/relation'

class NativeRecord
  attr_accessor :attributes, :color, :saved
  def initialize(attributes)
    @attributes = attributes
  end
  def save!
    raise 'missing color at validation' unless color
    @saved = true
  end
end
class NativeModel
  def self._table_sql = 'categories'
  def self.new(attributes) = NativeRecord.new(attributes)
end
class NativeRelation < ActiveRecord::Relation
  attr_accessor :match
  def find_by(_conditions) = match
  def add_condition(*) = true
end
relation = NativeRelation.new(NativeModel)
relation.mutable_where(user_id: 42, id: [1, 2])
raise 'wrong equality seed' unless relation.scope_attributes == {user_id: 42}
created = relation.find_or_create_by!(name: 'Food') { |record| record.color = '#123456' }
raise 'wrong attributes' unless created.attributes == {user_id: 42, name: 'Food'}
raise 'not saved' unless created.saved
relation.match = created
found = relation.find_or_create_by!(name: 'Food') { raise 'must not yield an existing record' }
raise 'wrong record' unless found.equal?(created)
puts 'Relation create/find, scoped attributes, block before validation: passed'
