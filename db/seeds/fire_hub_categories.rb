# frozen_string_literal: true

# Fire Hub category seed
#
# Creates the canonical Fire Hub category tree under a target user's family:
#
#   Fixed Costs (parent, expense)
#     └─ Mortgage, Hydro, Water, Internet, Cellphone, Daycare,
#        Property Tax, Insurance, Subscriptions
#   Variable Costs (parent, expense)
#     └─ Groceries, Restaurants, Gas, Entertainment, Kids,
#        Clothing, Medical, Gifts, Travel
#   Investment Income (parent, income)
#     └─ (children added per-account by user — e.g., "TFSA Distributions")
#
# Phase 3's FI coverage math will query by these parent names, so the names
# matter. Idempotent: re-running adds only what's missing.
#
# Usage:
#   FIRE_HUB_USER=you@example.com bin/rails runner db/seeds/fire_hub_categories.rb

email = ENV.fetch("FIRE_HUB_USER") do
  abort "❌ Set FIRE_HUB_USER=<your registered email> and rerun."
end

user = User.find_by(email: email)
abort "❌ No user found for email '#{email}'. Register at /registration/new first." unless user

family = user.family
puts "Seeding Fire Hub categories under family: #{family.name} (#{family.id})"

# Helper — finds an existing category by name within the family, or creates it.
def upsert_category(family, name, parent: nil, classification: "expense", color:, icon:)
  scope = family.categories.where(name: name)
  scope = scope.where(parent_id: parent&.id)
  existing = scope.first
  return existing if existing

  family.categories.create!(
    name: name,
    parent: parent,
    classification: classification,
    color: color,
    lucide_icon: icon
  )
end

# --- Fixed Costs ---
fixed_parent = upsert_category(family, "Fixed Costs",
                               classification: "expense",
                               color: "#4da568",
                               icon: "house")

fixed_children = {
  "Mortgage"      => "house",
  "Hydro"         => "lightbulb",
  "Water"         => "lightbulb",
  "Internet"      => "phone",
  "Cellphone"     => "phone",
  "Daycare"       => "baby",
  "Property Tax"  => "house",
  "Insurance"     => "shield-plus",
  "Subscriptions" => "ticket"
}
fixed_children.each do |name, icon|
  upsert_category(family, name,
                  parent: fixed_parent,
                  classification: "expense",
                  color: "#4da568",
                  icon: icon)
end

# --- Variable Costs ---
variable_parent = upsert_category(family, "Variable Costs",
                                  classification: "expense",
                                  color: "#df4e92",
                                  icon: "shopping-cart")

variable_children = {
  "Groceries"     => "apple",
  "Restaurants"   => "utensils",
  "Gas"           => "bus",
  "Entertainment" => "drama",
  "Kids"          => "baby",
  "Clothing"      => "shopping-cart",
  "Medical"       => "ambulance",
  "Gifts"         => "ribbon",
  "Travel"        => "briefcase"
}
variable_children.each do |name, icon|
  upsert_category(family, name,
                  parent: variable_parent,
                  classification: "expense",
                  color: "#df4e92",
                  icon: icon)
end

# --- Investment Income (parent only — children added per-account by user) ---
investment_income_parent = upsert_category(family, "Investment Income",
                                           classification: "income",
                                           color: "#e99537",
                                           icon: "circle-dollar-sign")

# --- Summary ---
puts ""
puts "✅ Done."
puts "   Fixed Costs:        #{fixed_parent.subcategories.count} children"
puts "   Variable Costs:     #{variable_parent.subcategories.count} children"
puts "   Investment Income:  #{investment_income_parent.subcategories.count} children"
puts ""
puts "Next: in the UI, create per-account distribution categories under"
puts "'Investment Income' as you receive distributions (e.g., 'TFSA Distributions',"
puts "'RRSP Distributions', 'Non-Reg Distributions'). Phase 3's coverage math will"
puts "sum income transactions whose category sits under 'Investment Income'."
