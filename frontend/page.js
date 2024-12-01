async function displayResults(data_promise) {
    let data = await data_promise;
    $("#overlay").fadeOut(300);
    console.log(data);


    jQuery.each(data['results'], function (key, value) {
        let row = $('<div class="row justify-content-center text-center slider"></div>').attr('id', key).click(function () {
            $("#" + key + "-content").slideToggle("fast");
        });
        row.append(`<h3>${key}</h3>`)
        
        let row_content = $('<div class="row justify-content-center text-center panel"></div>').attr('id', key + "-content").text("Lorem ipsum").click(function () {
            $("#" + key + "-content").slideToggle("fast");
        });
        $('#results').append(row, row_content);

        //jQuery.each()


    })

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
        $('#start').removeAttr('disabled');
    });

    $("#start").click(function () {
        const form_data = {
            instance_1: { process_engine: $("#cpee1").val(), execution_handler: $("#exe1").val() },
            instance_2: { process_engine: $("#cpee2").val(), execution_handler: $("#exe2").val() },
            test: $("#test_case").val()
        };

        $("#main").remove();
        $("#overlay").fadeIn(300);
        const settings = JSON.stringify(form_data);
        console.log(settings);
        $.ajax({
            url: run_tests_url,
            type: 'POST',
            data: settings,
            contentType: 'application/json',
            headers: { 'Content-ID': 'settings' }
        }).done(function (data) {
            console.log("post done");
            let res = getResult(run_tests_url, data);
            displayResults(res);
        });
    });
});

async function getResult(run_tests_url, ins) {
    let res = null;
    do {
        $.ajax({
            url: run_tests_url + ins,
            type: 'GET'
        }).done((data) => {
            res = data;

        })
        if ((res == null || res["status"] !== "finished")) { await delay(1500); }
    } while (res == null || res["status"] !== "finished");
    return res;
}

function delay(t) {
    return new Promise(resolve => {
        setTimeout(resolve, t);
    });
}
