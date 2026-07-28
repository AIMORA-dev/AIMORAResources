using AIMORACases

for descriptor in AIMORACases.available_cases()
    println(
        rpad(String(descriptor.id), 40),
        " study=",
        descriptor.study,
        " reference=",
        descriptor.reference_compatible,
    )
end
