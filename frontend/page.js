

jQuery(function ($) {
    $(document).ajaxSend(function () {
        $("#overlay").fadeIn(300);
    });
});
jQuery(function ($) {
    $(document).ajaxComplete(function () {
        setTimeout(function () {
            $("#overlay").fadeOut(300);
        }, 500);
    });
});
function displayResults(data) {
    results = JSON.parse(data);

}
$(document).ready(function () {


    let config_url = "https://echo.bpm.in.tum.de/fulltest/server/configuration";
    let run_tests_url = "https://echo.bpm.in.tum.de/fulltest/server/";

    $.ajax({
        url: config_url,
        type: 'GET',
        dataType: 'json',
        global: false
    }).done(function (data) {
        console.log(data)
        for (let index in data["process_engines"]) {
            let item = data["process_engines"][index]
            // console.log(item);
            $('select[name="process-engine-form"]').append($(new Option(item["name"], item["url"])));
        };
        for (let index in data['execution_handlers']) {
            let item = data['execution_handlers'][index];
            // console.log(item);
            $('select[name="executionhandler"]').append($(new Option(item, item)));
        };
        for (let index in data['tests']) {
            let item = data['tests'][index];
            $('#test_case').append($(new Option(item["name"], item['name'])));
        };
        console.log($("#start").attr("disabled"));
        $("#start").attr("disabled", false);
        console.log($("#start").attr("disabled"));
    });

    $("#start").click(function () {
        const form_data =  {
            instance_1: { process_engine: $("#cpee1").val(), execution_handler: $("#exe1").val() },
            instance_2: { process_engine: $("#cpee2").val(), execution_handler: $("#exe2").val() },
            test: $("#test_case").val()
        };

        $("#main").remove();
        const settings = JSON.stringify(form_data);
        console.log(settings)
        $.ajax({
            url: run_tests_url,
            type: 'POST',
            data: settings,
            contentType: 'application/json',
            headers: { 'Content-ID': 'settings' },
            success: function (data) {
                let ins = data["instance"];
            }
        });
        /*
        $.ajax({
            url: run_tests_url + ins,
            type: 'GET',
            dataType: 'json',
            success: function (data) {
                displayResults(data);
            }
        })
        */
    });
});