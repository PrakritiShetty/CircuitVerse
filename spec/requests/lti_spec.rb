# frozen_string_literal: true

require "rails_helper"

describe LtiController, type: :request do
    before do
        # shared keys for lms access
        @oauth_consumer_key_fromlms = "some_keys"
        @oauth_shared_secret_fromlms = "some_secrets"
        # default lti launch path
        @lti_launch_path = "/lti/launch"
        # sample request to get the test enviornemnt host and port info
        get "/"
        @host = request.host
        @port = request.port
    end

    describe "CircuitVerse as LTI Provider" do        
        before do
            # creation of assignment and required users
            @mentor = FactoryBot.create(:user)
            @group = FactoryBot.create(:group, mentor: @mentor)
            @member = FactoryBot.create(:user)
            @not_member = FactoryBot.create(:user)
            FactoryBot.create(:group_member, user: @member, group: @group)
            @assignment = FactoryBot.create(:assignment, group: @group, grading_scale: 2, lti_consumer_key: @oauth_consumer_key_fromlms, lti_shared_secret: @oauth_shared_secret_fromlms)
        end

        context "when lti parameters are valid" do
            it "returns unauthorized (401) if student is not in the group" do
                data = consumer_data(@oauth_consumer_key_fromlms, @oauth_shared_secret_fromlms, parameters(@not_member.email))
                post @lti_launch_path, params: data, headers: { "Content-Type": "application/x-www-form-urlencoded" }
                expect(response.code).to eq("401")
            end

            it "returns success (200) if student is in the group" do
                data = consumer_data(@oauth_consumer_key_fromlms, @oauth_shared_secret_fromlms, parameters(@member.email))
                post @lti_launch_path, params: data, headers: { "Content-Type": "application/x-www-form-urlencoded" }
                expect(response.code).to eq("200")
            end

            it "redirect (302) to assignment page if user is teacher" do
                data = consumer_data(@oauth_consumer_key_fromlms, @oauth_shared_secret_fromlms, parameters(@mentor.email))
                post @lti_launch_path, params: data, headers: { "Content-Type": "application/x-www-form-urlencoded" }
                expect(response.code).to eq("302")
            end
        end

        context "when lti parameters are invalid" do
            it "returns unauthorized (401) if no parameters present" do
                # post to launch url without any parameters
                post @lti_launch_path
                expect(response.code).to eq("401")
            end

            it "returns unauthorized (401) if parameters contains invalid assignment credentials" do
                data = consumer_data("some_random", "some_random_secret", parameters(@member.email))
                post @lti_launch_path, params: data, headers: { "Content-Type": "application/x-www-form-urlencoded" }
                expect(response.code).to eq("401")
            end
        end

        def launch_uri
            # required for generation of LTI parameters
            launch_url = "http://#{@host}:#{@port}/lti/launch"
            URI(launch_url)
        end

        def parameters(member_email)
            {
                'launch_url' => launch_uri().to_s,
                'user_id' => SecureRandom.hex(4),
                'launch_presentation_return_url' => launch_uri().to_s,
                'lti_version' => 'LTI-1p0',
                'lti_message_type' => 'basic-lti-launch-request',
                'resource_link_id' => '88391-e1919-bb3456',
                'lis_person_contact_email_primary' => member_email,
                'tool_consumer_info_product_family_code' => 'moodle',
                'context_title' => 'sample Course',
                'lis_result_sourcedid' => SecureRandom.hex(10)
            } 
        end

        def consumer_data(oauth_consumer_key_fromlms, oauth_shared_secret_fromlms, parameters)
            consumer = IMS::LTI::ToolConsumer.new(oauth_consumer_key_fromlms, oauth_shared_secret_fromlms, parameters)
            allow(consumer).to receive(:to_params).and_return(parameters)
            consumer.generate_launch_data
        end
    end
end