class IncomesController < ApplicationController
  def index
    incomes = Income.all
    render json: incomes
  end
end