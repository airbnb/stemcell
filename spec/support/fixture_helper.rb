module FixtureHelper
  def self.chef_repo_fixture_path
    File.expand_path("../../fixtures/chef_repo", __FILE__)
  end

  def self.expected_metadata_path
    File.join(chef_repo_fixture_path, 'roles-expected-metadata')
  end

  def self.expected_metadata_for_role(role)
    fixture_path = File.join(expected_metadata_path, "#{role}.json")
    JSON.parse(File.read(fixture_path))
  end
end
