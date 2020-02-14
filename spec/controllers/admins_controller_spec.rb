# frozen_string_literal: true

# BigBlueButton open source conferencing system - http://www.bigbluebutton.org/.
#
# Copyright (c) 2018 BigBlueButton Inc. and by respective authors (see below).
#
# This program is free software; you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free Software
# Foundation; either version 3.0 of the License, or (at your option) any later
# version.
#
# BigBlueButton is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License along
# with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.

require "rails_helper"

describe AdminsController, type: :controller do
  before do
    allow_any_instance_of(ApplicationController).to receive(:set_user_domain).and_return("provider1")
    controller.instance_variable_set(:@user_domain, "provider1")

    @user = create(:user, provider: "provider1")
    @admin = create(:user, provider: "provider1")
    @admin.add_role :admin
  end

  describe "User Roles" do
    before do
      allow(Rails.configuration).to receive(:enable_email_verification).and_return(true)
    end

    context "GET #index" do
      it "renders a 404 if a user tries to acccess it" do
        @request.session[:user_id] = @user.id
        get :index

        expect(response).to render_template(:greenlight_error)
      end

      it "renders the admin settings if an admin tries to acccess it" do
        @request.session[:user_id] = @admin.id
        get :index

        expect(response).to render_template(:index)
      end
    end

    context "GET #edit_user" do
      it "renders the index page" do
        @request.session[:user_id] = @admin.id

        get :edit_user, params: { user_uid: @user.uid }

        expect(response).to render_template(:edit_user)
      end
    end

    context "POST #ban" do
      it "bans a user from the application" do
        @request.session[:user_id] = @admin.id

        expect(@user.has_role?(:denied)).to eq(false)

        post :ban_user, params: { user_uid: @user.uid }

        expect(@user.has_role?(:denied)).to eq(true)
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(admins_path)
      end
    end

    context "POST #unban" do
      it "unbans the user from the application" do
        @request.session[:user_id] = @admin.id
        @user.add_role :denied

        expect(@user.has_role?(:denied)).to eq(true)

        post :unban_user, params: { user_uid: @user.uid }

        expect(@user.has_role?(:denied)).to eq(false)
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(admins_path)
      end
    end

    context "POST #invite" do
      before do
        allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
        allow_any_instance_of(ApplicationController).to receive(:allow_greenlight_accounts?).and_return(true)
        allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)
      end

      it "invites a user" do
        @request.session[:user_id] = @admin.id
        email = Faker::Internet.email
        post :invite, params: { invite_user: { email: email } }

        invite = Invitation.find_by(email: email, provider: "provider1")

        expect(invite.present?).to eq(true)
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(admins_path)
      end

      it "sends an invitation email" do
        @request.session[:user_id] = @admin.id
        email = Faker::Internet.email

        params = { invite_user: { email: email } }
        expect { post :invite, params: params }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "invites multiple users" do
        @request.session[:user_id] = @admin.id
        email = "#{Faker::Internet.email},#{Faker::Internet.email},#{Faker::Internet.email},#{Faker::Internet.email}"
        post :invite, params: { invite_user: { email: email } }

        invite = Invitation.find_by(email: email.split(",")[0], provider: "provider1")
        expect(invite.present?).to eq(true)

        invite1 = Invitation.find_by(email: email.split(",")[1], provider: "provider1")
        expect(invite1.present?).to eq(true)

        invite2 = Invitation.find_by(email: email.split(",")[2], provider: "provider1")
        expect(invite2.present?).to eq(true)

        invite3 = Invitation.find_by(email: email.split(",")[3], provider: "provider1")
        expect(invite3.present?).to eq(true)

        expect(flash[:success]).to be_present
        expect(response).to redirect_to(admins_path)
      end

      it "sends multiple invitation emails" do
        @request.session[:user_id] = @admin.id
        email = "#{Faker::Internet.email},#{Faker::Internet.email},#{Faker::Internet.email},#{Faker::Internet.email}"

        params = { invite_user: { email: email } }
        expect { post :invite, params: params }.to change { ActionMailer::Base.deliveries.count }.by(4)
      end
    end

    context "POST #approve" do
      it "approves a pending user" do
        @request.session[:user_id] = @admin.id

        @user.add_role :pending

        post :approve, params: { user_uid: @user.uid }

        expect(@user.has_role?(:pending)).to eq(false)
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(admins_path)
      end

      it "sends the user an email telling them theyre approved" do
        @request.session[:user_id] = @admin.id

        @user.add_role :pending
        params = { user_uid: @user.uid }
        expect { post :approve, params: params }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end

    context "POST #undelete" do
      it "undeletes a user" do
        @request.session[:user_id] = @admin.id

        @user.delete

        expect(User.find_by(uid: @user.uid)).to be_nil

        post :undelete, params: { user_uid: @user.uid }

        expect(User.find_by(uid: @user.uid)).to be_present
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(admins_path)
      end

      it "undeletes the users rooms" do
        @request.session[:user_id] = @admin.id

        @user.main_room.delete
        @user.delete

        expect(Room.find_by(uid: @user.main_room.uid)).to be_nil

        post :undelete, params: { user_uid: @user.uid }

        expect(Room.find_by(uid: @user.main_room.uid)).to be_present
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(admins_path)
      end
    end

    context "POST #merge_user" do
      it "merges the users room to the primary account and deletes the old user" do
        @request.session[:user_id] = @admin.id

        @user2 = create(:user)
        room1 = create(:room, owner: @user2)
        room2 = create(:room, owner: @user2)
        room3 = @user2.main_room

        post :merge_user, params: { user_uid: @user.uid, merge: @user2.uid }

        room1.reload
        room2.reload
        room3.reload

        expect(User.exists?(uid: @user2.uid)).to be false
        expect(room1.name).to start_with("(Merged)")
        expect(room2.name).to start_with("(Merged)")
        expect(room3.name).to start_with("(Merged)")
        expect(room1.owner).to eq(@user)
        expect(room2.owner).to eq(@user)
        expect(room3.owner).to eq(@user)
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(admins_path)
      end

      it "does not merge if trying to merge the same user into themself" do
        @request.session[:user_id] = @admin.id

        post :merge_user, params: { user_uid: @user.uid, merge: @user.uid }

        expect(flash[:alert]).to be_present
        expect(response).to redirect_to(admins_path)
      end
    end
  end

  describe "User Design" do
    context "POST #branding" do
      it "changes the branding image on the page" do
        allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
        allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)

        @request.session[:user_id] = @admin.id
        fake_image_url = "example.com"

        post :update_settings, params: { setting: "Branding Image", value: fake_image_url }

        feature = Setting.find_by(provider: "provider1").features.find_by(name: "Branding Image")

        expect(feature[:value]).to eq(fake_image_url)
        expect(response).to redirect_to(admin_site_settings_path)
      end
    end

    context "POST #coloring" do
      it "changes the primary on the page" do
        allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
        allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)

        @request.session[:user_id] = @admin.id
        primary_color = Faker::Color.hex_color

        post :coloring, params: { value: primary_color }

        feature = Setting.find_by(provider: "provider1").features.find_by(name: "Primary Color")

        expect(feature[:value]).to eq(primary_color)
        expect(response).to redirect_to(admin_site_settings_path)
      end

      it "changes the primary-lighten on the page" do
        allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
        allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)

        @request.session[:user_id] = @admin.id
        primary_color = Faker::Color.hex_color

        post :update_settings, params: { setting: "Primary Color Lighten", value: primary_color }

        feature = Setting.find_by(provider: "provider1").features.find_by(name: "Primary Color Lighten")

        expect(feature[:value]).to eq(primary_color)
        expect(response).to redirect_to(admin_site_settings_path)
      end

      it "changes the primary-darken on the page" do
        allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
        allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)

        @request.session[:user_id] = @admin.id
        primary_color = Faker::Color.hex_color

        post :update_settings, params: { setting: "Primary Color Darken", value: primary_color }

        feature = Setting.find_by(provider: "provider1").features.find_by(name: "Primary Color Darken")

        expect(feature[:value]).to eq(primary_color)
        expect(response).to redirect_to(admin_site_settings_path)
      end
    end
  end

  describe "Site Settings" do
    context "POST #registration_method" do
      it "changes the registration method for the given context" do
        allow(Rails.configuration).to receive(:enable_email_verification).and_return(true)
        allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
        allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)

        @request.session[:user_id] = @admin.id

        post :registration_method, params: { value: "invite" }

        feature = Setting.find_by(provider: "provider1").features.find_by(name: "Registration Method")

        expect(feature[:value]).to eq(Rails.configuration.registration_methods[:invite])
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(admin_site_settings_path)
      end

      it "does not allow the user to change to invite if emails are off" do
        allow(Rails.configuration).to receive(:enable_email_verification).and_return(false)
        allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
        allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)

        @request.session[:user_id] = @admin.id

        post :registration_method, params: { value: "invite" }

        expect(flash[:alert]).to be_present
        expect(response).to redirect_to(admin_site_settings_path)
      end
    end

    context "POST #room_authentication" do
      it "changes the room authentication required setting" do
        allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
        allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)

        @request.session[:user_id] = @admin.id

        post :update_settings, params: { setting: "Room Authentication", value: "true" }

        feature = Setting.find_by(provider: "provider1").features.find_by(name: "Room Authentication")

        expect(feature[:value]).to eq("true")
        expect(response).to redirect_to(admin_site_settings_path)
      end
    end

    context "POST #room_limit" do
      it "changes the room limit setting" do
        allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
        allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)

        @request.session[:user_id] = @admin.id

        post :update_settings, params: { setting: "Room Limit", value: 5 }

        feature = Setting.find_by(provider: "provider1").features.find_by(name: "Room Limit")

        expect(feature[:value]).to eq("5")
        expect(response).to redirect_to(admin_site_settings_path)
      end
    end

    context "POST #default_recording_visibility" do
      it "changes the default recording visibility setting" do
        allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
        allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)

        @request.session[:user_id] = @admin.id

        post :update_settings, params: { setting: "Default Recording Visibility", value: "public" }

        feature = Setting.find_by(provider: "provider1").features.find_by(name: "Default Recording Visibility")

        expect(feature[:value]).to eq("public")
        expect(response).to redirect_to(admin_site_settings_path)
      end
    end

    context "POST #shared_access" do
      it "changes the shared access setting" do
        allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
        allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)

        @request.session[:user_id] = @admin.id

        post :update_settings, params: { setting: "Shared Access", value: "false" }

        feature = Setting.find_by(provider: "provider1").features.find_by(name: "Shared Access")

        expect(feature[:value]).to eq("false")
        expect(response).to redirect_to(admin_site_settings_path)
      end
    end

    context "POST #clear_auth" do
      it "clears all users social uids if clear auth button is clicked" do
        allow_any_instance_of(ApplicationController).to receive(:set_user_domain).and_return("provider1")
        controller.instance_variable_set(:@user_domain, "provider1")

        @request.session[:user_id] = @admin.id

        @admin.add_role :super_admin
        @admin.update_attribute(:provider, "greenlight")
        @user2 = create(:user, provider: "provider1")
        @user3 = create(:user, provider: "provider1")

        @user.update_attribute(:social_uid, Faker::Internet.password)
        @user2.update_attribute(:social_uid, Faker::Internet.password)
        @user3.update_attribute(:social_uid, Faker::Internet.password)

        expect(@user.social_uid).not_to be(nil)
        expect(@user2.social_uid).not_to be(nil)
        expect(@user3.social_uid).not_to be(nil)

        post :clear_auth

        @user.reload
        @user2.reload
        @user3.reload

        expect(@user.social_uid).to be(nil)
        expect(@user2.social_uid).to be(nil)
        expect(@user3.social_uid).to be(nil)
      end
    end
  end

  describe "Roles" do
    context "GET #roles" do
      it "should render the roles editor with the user role selected" do
        @request.session[:user_id] = @admin.id

        get :roles

        expect(response).to render_template :roles
        expect(assigns(:roles).count).to eq(2)
        expect(assigns(:selected_role).name).to eq("user")
      end

      it "should render the roles editor with the request role selected" do
        Role.create_default_roles("provider1")

        new_role = Role.create(name: "test", provider: "provider1")

        @request.session[:user_id] = @admin.id

        get :roles, params: { selected_role: new_role.id }

        expect(response).to render_template :roles
        expect(assigns(:roles).count).to eq(3)
        expect(assigns(:selected_role).name).to eq(new_role.name)
      end
    end

    context "POST #new_role" do
      before do
        Role.create_default_roles("provider1")
      end

      it "should fail with duplicate role name" do
        @request.session[:user_id] = @admin.id

        post :new_role, params: { role: { name: "admin" } }

        expect(response).to redirect_to admin_roles_path
        expect(flash[:alert]).to eq(I18n.t("administrator.roles.invalid_create"))
      end

      it "should fail with empty role name" do
        @request.session[:user_id] = @admin.id

        post :new_role, params: { role: { name: "    " } }

        expect(response).to redirect_to admin_roles_path
        expect(flash[:alert]).to eq(I18n.t("administrator.roles.invalid_create"))
      end

      it "should create new role and increase user role priority" do
        @request.session[:user_id] = @admin.id

        post :new_role, params: { role: { name: "test" } }

        new_role = Role.find_by(name: "test", provider: "provider1")
        user_role = Role.find_by(name: "user", provider: "provider1")

        expect(new_role.priority).to eq(1)
        expect(user_role.priority).to eq(2)
        expect(response).to redirect_to admin_roles_path(selected_role: new_role.id)
      end
    end

    context "PATCH #change_role_order" do
      before do
        Role.create_default_roles("provider1")
      end

      it "should fail if user attempts to change the order of the admin or user roles" do
        @request.session[:user_id] = @admin.id

        user_role = Role.find_by(name: "user", provider: "provider1")
        admin_role = Role.find_by(name: "admin", provider: "provider1")

        patch :change_role_order, params: { role: [user_role.id, admin_role.id] }

        expect(flash[:alert]).to eq(I18n.t("administrator.roles.invalid_order"))
        expect(response).to redirect_to admin_roles_path
      end

      it "should fail if a user attempts to edit a role with a higher priority than their own" do
        Role.create(name: "test1", priority: 1, provider: "greenlight")
        new_role2 = Role.create(name: "test2", priority: 2, provider: "greenlight")
        new_role2.update_permission("can_edit_roles", "true")
        new_role3 = Role.create(name: "test3", priority: 3, provider: "greenlight")
        user_role = Role.find_by(name: "user", provider: "greenlight")

        user_role.priority = 4
        user_role.save!

        @user.roles << new_role2
        @user.save!

        @request.session[:user_id] = @user.id

        patch :change_role_order, params: { role: [new_role3.id, new_role2.id] }

        expect(flash[:alert]).to eq(I18n.t("administrator.roles.invalid_order"))
        expect(response).to redirect_to admin_roles_path
      end

      it "should fail if a user attempts to edit a role with a higher priority than their own" do
        Role.create(name: "test1", priority: 1, provider: "greenlight")
        new_role2 = Role.create(name: "test2", priority: 2, provider: "greenlight")
        new_role2.update_permission("can_edit_roles", "true")
        new_role3 = Role.create(name: "test3", priority: 3, provider: "greenlight")
        user_role = Role.find_by(name: "user", provider: "greenlight")

        user_role.priority = 4
        user_role.save!

        @user.roles << new_role2
        @user.save!

        @request.session[:user_id] = @user.id

        patch :change_role_order, params: { role: [new_role3.id, new_role2.id] }

        expect(flash[:alert]).to eq(I18n.t("administrator.roles.invalid_order"))
        expect(response).to redirect_to admin_roles_path
      end

      it "should update the role order" do
        new_role1 = Role.create(name: "test1", priority: 1, provider: "provider1")
        new_role2 = Role.create(name: "test2", priority: 2, provider: "provider1")
        new_role3 = Role.create(name: "test3", priority: 3, provider: "provider1")
        user_role = Role.find_by(name: "user", provider: "provider1")

        @request.session[:user_id] = @admin.id

        patch :change_role_order, params: { role: [new_role3.id, new_role2.id, new_role1.id] }

        new_role1.reload
        new_role2.reload
        new_role3.reload
        user_role.reload

        expect(new_role3.priority).to eq(1)
        expect(new_role2.priority).to eq(2)
        expect(new_role1.priority).to eq(3)
        expect(user_role.priority).to eq(4)
      end
    end

    context 'POST #update_role' do
      before do
        Role.create_default_roles("provider1")
      end

      it "should fail to update a role with a lower priority than the user" do
        new_role1 = Role.create(name: "test1", priority: 1, provider: "provider1")
        new_role2 = Role.create(name: "test2", priority: 2, provider: "provider1")
        new_role2.update_permission("can_edit_roles", "true")
        user_role = Role.find_by(name: "user", provider: "greenlight")

        user_role.priority = 3
        user_role.save!

        @user.roles << new_role2
        @user.save!

        @request.session[:user_id] = @user.id

        patch :update_role, params: { role_id: new_role1.id }

        expect(flash[:alert]).to eq(I18n.t("administrator.roles.invalid_update"))
        expect(response).to redirect_to admin_roles_path(selected_role: new_role1.id)
      end

      it "should fail to update if there is a duplicate name" do
        new_role = Role.create(name: "test2", priority: 1, provider: "provider1")
        new_role.update_permission("can_edit_roles", "true")

        @request.session[:user_id] = @admin.id

        patch :update_role, params: { role_id: new_role.id, role: { name: "admin" } }

        expect(flash[:alert]).to eq(I18n.t("administrator.roles.invalid_update"))
        expect(response).to redirect_to admin_roles_path(selected_role: new_role.id)
      end

      it "should update role permisions" do
        new_role = Role.create(name: "test2", priority: 1, provider: "provider1")
        new_role.update_permission("can_edit_roles", "true")

        @request.session[:user_id] = @admin.id

        patch :update_role, params: { role_id: new_role.id, role: { name: "test", can_edit_roles: false,
          colour: "#45434", can_manage_users: true } }

        new_role.reload
        expect(new_role.name).to eq("test")
        expect(new_role.get_permission("can_edit_roles")).to eq(false)
        expect(new_role.colour).to eq("#45434")
        expect(new_role.get_permission("can_manage_users")).to eq(true)
        expect(new_role.get_permission("send_promoted_email")).to eq(false)
        expect(response).to redirect_to admin_roles_path(selected_role: new_role.id)
      end
    end

    context "DELETE delete_role" do
      before do
        Role.create_default_roles("provider1")
      end

      it "should fail to delete the role if it has users assigned to it" do
        admin_role = Role.find_by(name: "admin", provider: "greenlight")

        @request.session[:user_id] = @admin.id

        delete :delete_role, params: { role_id: admin_role.id }

        expect(flash[:alert]).to eq(I18n.t("administrator.roles.role_has_users", user_count: 1))
        expect(response).to redirect_to admin_roles_path(selected_role: admin_role.id)
      end

      it "should fail to delete the role if it is a default role" do
        pending_role = Role.find_by(name: "pending", provider: "provider1")

        @request.session[:user_id] = @admin.id

        delete :delete_role, params: { role_id: pending_role.id }

        expect(response).to redirect_to admin_roles_path(selected_role: pending_role.id)
      end

      it "should successfully delete the role" do
        new_role = Role.create(name: "test2", priority: 1, provider: "provider1")
        new_role.update_permission("can_edit_roles", "true")

        @request.session[:user_id] = @admin.id

        delete :delete_role, params: { role_id: new_role.id }

        expect(Role.where(name: "test2", provider: "provider1").count).to eq(0)
        expect(response).to redirect_to admin_roles_path
      end
    end
  end
end
