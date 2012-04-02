Feature: Image Blocks
  So that I can create image blocks
  As a content editor
  I want to upload an image

  Background:
    Given I am logged in as a Content Editor
    And I am adding a New Image

    Scenario: Creating image block
      When I fill in "Name" with "Giraffe"
      And I attach the file "test/fixtures/giraffe.jpeg" to "File"
      And I select "My Site" from "section_id"
      And I fill in "Path" with "/giraffe.jpeg"
      And I Save And Publish
      Then I should see "Image 'Giraffe' was created"
      And I should see an image with path "/giraffe.jpeg"
      And the attachment with path "/giraffe.jpeg" should be in section "My Site"

    Scenario: Creating an image block with errors
      When I Save And Publish
      Then I should see "Name can't be blank"
      When I fill in "image_block_name" with "Giraffe"
      And I Save And Publish
      Then I should see "You must upload a file"
      When I attach the file "test/fixtures/giraffe.jpeg" to "image_block_assets_attributes_0_data"
      And I Save And Publish
      Then I should see "file path can't be blank"
      When I fill in "image_block_assets_attributes_0_data_file_path" with "/giraffe.jpeg"
      And I attach the file "test/fixtures/giraffe.jpeg" to "image_block_assets_attributes_0_data"
      And I Save And Publish
      Then I should see "Image 'Giraffe' was created"


