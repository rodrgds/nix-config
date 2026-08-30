if type == "object"
  and (keys | sort == ["repository", "sha"])
  and .repository == "rodrgds/personal-website"
  and (.sha | type == "string" and test("^[0-9a-f]{40}$"))
then .
else error("invalid personal website deployment payload")
end
