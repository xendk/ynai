# frozen_string_literal: true

Sequel.migration do
  up do
    from(:config).where(name: 'push.accounts').delete
    from(:config).where(name: 'push.mapping').delete
  end
end
