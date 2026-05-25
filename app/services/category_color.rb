class CategoryColor
  PALETTE = %w[
    #2563eb #059669 #dc2626 #7c3aed #0891b2
    #ca8a04 #c2410c #be185d #4f46e5 #0f766e
  ].freeze

  def self.pick(name)
    PALETTE[name.to_s.bytes.sum % PALETTE.size]
  end
end
