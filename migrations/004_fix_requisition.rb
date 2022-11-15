# frozen_string_literal: true

Sequel.migration do
  up do
    from(:config).where(name: 'fetch.requsition_id').update(name: 'fetch.requisition_id')
  end

  down do
    from(:config).where(name: 'fetch.requisition_id').update(name: 'fetch.requsition_id')
  end
end
