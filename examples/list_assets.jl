using AIMORACatalogs

for entry in AIMORACatalogs.available_assets()
    println(
        rpad(String(entry.id), 36),
        " class=",
        entry.equipment_class,
        " tabs=",
        join(AIMORACatalogs.study_tabs(entry), ","),
    )
end
