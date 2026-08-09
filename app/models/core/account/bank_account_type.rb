module Core::Account::BankAccountType
  CHECKING = "checking"
  SAVINGS = "savings"
  INVESTMENT = "investment"
  SALARY = "salary"

  ALL = [ CHECKING, SAVINGS, INVESTMENT, SALARY ].freeze
end
