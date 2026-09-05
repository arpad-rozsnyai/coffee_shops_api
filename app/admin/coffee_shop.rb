# frozen_string_literal: true

ActiveAdmin.register CoffeeShop do
  actions :index, :new, :create, :edit, :update, :destroy

  permit_params :name, :x, :y, :address, :open_until

  index do
    column :id
    column :name
    column("X", sortable: :coordinate_x, &:x)
    column("Y", sortable: :coordinate_y, &:y)
    column :address
    column :open_until
    actions
  end

  filter :id
  filter :name

  form do |f|
    f.inputs do
      f.input :name
      f.input :x
      f.input :y
      f.input :address
      f.input :open_until
    end
    f.actions
  end

  # address/open_until required here only, not as a CoffeeShop model validation (see CLAUDE.md).
  controller do
    def create_resource(object)
      return super unless required_fields_blank?(object)

      add_required_field_errors(object)
      false
    end

    def update_resource(object, attributes)
      submitted = attributes.first || {}
      return super unless submitted[:address].blank? || submitted[:open_until].blank?

      object.assign_attributes(submitted)
      add_required_field_errors(object)
      false
    end

    private

    def required_fields_blank?(coffee_shop)
      coffee_shop.address.blank? || coffee_shop.open_until.blank?
    end

    def add_required_field_errors(coffee_shop)
      coffee_shop.errors.add(:address, :blank) if coffee_shop.address.blank?
      coffee_shop.errors.add(:open_until, :blank) if coffee_shop.open_until.blank?
    end
  end
end
