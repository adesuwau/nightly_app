require 'pry'

describe("The Main Page")do

  it("displays the site name")do
    visit("/")
    # binding.pry
    expect(page).to have_content("night.ly")
  end

  it("requests that the user register")do
  visit("/")
  expect(page).to have_content ("register")
  end

    it("requests that the user login with github")do
  visit("/")
  expect(page).to have_content ("Login With Github")
  end
end

describe("Profile Edit")do

  it("gives a total")do
  visit("/")
  click_on "Calculate Rats"
  #when we click on links we can be redirected
  #now we are on rat store
  number_of_rats = (1..100).to_a.sample
  fill_in "Quantity of Rats", with: number_of_rats
  click_button "Calculate"
  expect(page).to have_content "That's $#{number_of_rats * 10} worth of rats!"
  end
end
