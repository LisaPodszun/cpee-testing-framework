async function displayResults(data_promise) {
    let data = await data_promise;
    $("#overlay").fadeOut(300);
    console.log(data);


    jQuery.each(data['results'], function (key, value) {
        let row_content = $('<div class="row justify-content-center panel mx-5 border-top-0 border-primary"></div>').attr('id', key + "-content");
        let row = $('<div class="row justify-content-center slider mt-3 mx-5"></div>').attr('id', key).click(function () {
            row_content.slideToggle("fast");
        });
        row.append(`<h4 class="headings">${key}</h4>`);

        inner_col = $('<div class="col"></div>');
        row_content.append(inner_col);

        let matches_ins_1 = value['matches'][0];
        let matches_ins_2 = value['matches'][1];

        let maxxed = false;
        let index_2 = 0;
        // Generate all for matches from 1 to 2

        for (const [ind_1, ind_2] of Object.entries(matches_ins_1)) {
            // put matching elements here
            let log_match_id = ind_1.toString() + ind_2.toString();
            let inner_row = $(`<div class="row slider mx-3 my-1 border-bottom-0" id=${log_match_id}></div>`);
            let inner_row_panel = $('<div class="row panel mx-3 table"></div>');
            inner_row.click(function (e) {
                inner_row_panel.slideToggle("fast");
                inner_row_panel.css("display", "flex");
                e.stopPropagation();
            });

            inner_row.append(`<h5 class='headings'>${value['log_instance_1'][ind_1]['channel']}</h5>`);
            
            let ins_1_log = $('<div class="col"></div>').html('<h5 class="text-center my-1">Instance 1</h5>');
            let json_1 = $('<pre></pre>').text(JSON.stringify((value['log_instance_1'][ind_1]['message']), undefined, 2));
            ins_1_log.append(json_1);
            let ins_2_log = $('<div class="col"></div>').html('<h5 class="text-center my-1">Instance 2</h5>');
            if (ind_2 == "only_ins_1") {
                inner_row.css('background', 'linear-gradient(to right, #0065bd 0%,#0065bd 60%, #fc6262 80%,#fc6262 100%)');
                ins_2_log.append(ind_2);
            } 
            else if (ind_2 == "no_match") {
                inner_row.css('background', 'linear-gradient(to right,#0065bd 0%,#0065bd 60%, #fefa77 80%,#fefa77 100%)');
                ins_2_log.append(ind_2);
            }
            else {
                inner_row.css('background', 'linear-gradient(to right,#0065bd 0%,#0065bd 60%, #88fe77 80%,#88fe77 100%)');
                json_2 = $('<pre></pre>').text(JSON.stringify(value['log_instance_2'][ind_2]['message'], undefined, 2));
                ins_2_log.append(json_2);
            }
            inner_row_panel.append(ins_1_log, ins_2_log);
            inner_col.append(inner_row, inner_row_panel);
        }

        for (const [ind_2, ind_1] of Object.entries(matches_ins_2)) {
            if (ind_1 == "no_match" || ind_1 == "only_ins_2") {
                let log_match_id = ind_2.toString() + ind_1.toString();
                let inner_row = $(`<div class="row slider mx-3 my-1 border-bottom-0 id=${log_match_id}"></div>`);
                let inner_row_panel = $('<div class="row panel mx-3 border-bottom-0 border-primary table"></div>');
                inner_row.click(function (e) {
                    inner_row_panel.slideToggle("fast");
                    inner_row_panel.css("display", "flex");
                    e.stopPropagation();
                });
                // put one block [matches_ins_2[index_2]  || ins_2_element ]
                inner_row.append(`<h5 class='headings'>${value['log_instance_2'][ind_2]['channel']}</h5>`);
                let ins_1_log = $('<div class="col"><h5 class="text-center my-1">Instance 1</h5></div>').append(ind_1);
                let ins_2_log = $('<div class="col"></div>').html('<h5 class="text-center my-1">Instance 2</h5>');
                let json_2 = $('<pre></pre>').text(JSON.stringify(value['log_instance_2'][ind_2]['message'], undefined, 2));
                ins_2_log.append(json_2);
                if (ind_1 == "no_match") {
                    inner_row.css('background', 'linear-gradient(to right,#0065bd 0%,#0065bd 60%, #fefa77 80%,#fefa77 100%)');
                }
                else {
                    inner_row.css('background', 'linear-gradient(to right, #0065bd 0%,#0065bd 60%, #fc6262 80%,#fc6262 100%)');
                }
                inner_row_panel.append(ins_1_log, ins_2_log);
                inner_col.append(inner_row, inner_row_panel);
            }
        }

        $('#results').append(row, row_content);
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
