let upstream = https://github.com/dfinity/vessel-package-set/releases/download/mo-0.8.3-20230224/package-set.dhall sha256:df71395fc48d1a0f41c0b49a0a6e0490d0b52641a86a9d51651bf2622e87fbff
let Package =
    { name : Text, version : Text, repo : Text, dependencies : List Text }

let
  -- This is where you can add your own packages to the package-set
  additions =
    [] : List Package

let
  -- This is where you can override existing packages in the package-set
  overrides = [] : List Package

in  upstream # additions # overrides
