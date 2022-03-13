# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [defq: 2],
  export: [
    locals_without_parens: [defq: 2]
  ]
]
