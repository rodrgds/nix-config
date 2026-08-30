if type == "object"
  and (keys | sort == ["digest", "repository", "sha", "tag"])
  and .repository == "getopenpost/openpost"
  and (.sha | type == "string" and test("^[0-9a-f]{40}$"))
  and (.tag | type == "string" and test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))
  and (.digest | type == "string" and test("^sha256:[0-9a-f]{64}$"))
then .
else error("invalid OpenPost deployment payload")
end
