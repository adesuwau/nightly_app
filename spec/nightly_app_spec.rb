require 'pry'

describe("The Main Page")do

  it("displays the site name")do
    visit("/")
    # binding.pry
    expect(page).to have_content("night.ly")
  end

  it("requests that the user login with github")do
    visit("/")
    expect(page).to have_content ("Login With Github")
  end

end


