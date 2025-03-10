String.prototype.replaceAt = function (index, end_index, replacement) {
    return this.substring(0, index) + replacement + this.substring(end_index);
}

function markInnerStructureResults(log_entry, index, differences_hash) {
    console.log("In structure marking");
    for (const [ind, value] of Object.entries(differences_hash[index])) {
        keys = value.split("_");
        console.log("Current key to find:" + keys)
        element_index = 0;
        for (i = 0; i < keys.length; i++) {
            element_index = log_entry.indexOf("\"" + keys[i] + "\"", element_index);
            console.log("Current start index" + element_index);
            end_index = log_entry.indexOf(":", element_index);
        }
        console.log("Current End Index:" + end_index);
        text_to_highlight = log_entry.substring(element_index, end_index);
        console.log("Corresponding text to hightlight:" + text_to_highlight);

        log_entry = log_entry.replaceAt(element_index, end_index, "<span class='red'>" + text_to_highlight + "</span>");
    }
    console.log("Result:" + log_entry);
    return log_entry
}

function markInnerContentResults(log_entry, index, differences_hash) {
    for (const [ind, value] of Object.entries(differences_hash[index])) {
        keys = value.split("_");
        element_index = 0;
        for (i = 0; i < keys.length; i++) {
            element_index = log_entry.indexOf("\"" + keys[i] + "\"", element_index);
            console.log("Index of " + keys[i] + ": " + element_index)
        }
        element_index = log_entry.indexOf(' ', element_index) + 1;
        tmp = log_entry.substring(element_index, log_entry.length - 1);
        // Symbol that signals the start of the entry, can be " for strings or {, [ for hashes or arrays
        special_symbol = tmp[0];
        if (special_symbol  == "\"" || special_symbol  == " ") {
            end_index = tmp.search(/\n/);
        } else {
            open_symbols = 1;
            current_index = 1;
            while (open_symbols > 0) {
                if (special_symbol == "{") {
                    if (tmp[current_index] == "{") {
                        open_symbols++;
                    } else if (tmp[current_index] == "}") {
                        open_symbols--;
                    }
                } else if (special_symbol == "[") {
                    if (tmp[current_index] == "[") {
                        open_symbols++;
                    } else if (tmp[current_index] == "]") {
                        open_symbols--;
                    }
                } else {
                    alert("Unexpected symbol: " + special_symbol + " in log entry: " + log_entry)
                    return
                }
                current_index++;
            }
            end_index = current_index;
        }
        if (tmp[end_index] == ',') {
            console.log("Is the last letter a , ?" + tmp[end_index]);
            end_index = end_index - 1;
        }
        end_index = end_index + element_index;
        text_to_highlight = log_entry.substring(element_index, end_index);
        log_entry = log_entry.replace(text_to_highlight, "<span class='yellow'>" + text_to_highlight + "</span>");
    }
    return log_entry
}

async function displayResults(data_promise, appendto) {
    let data = await data_promise;
    $("#overlay").fadeOut(300);

    jQuery.each(data['results'], function (key, value) {
        let row_content = $('<div class="row justify-content-center panel mx-5 border-top-0 border-primary"></div>').attr('id', key + "-content");
        let row = $('<div class="row justify-content-center slider mt-3 mx-5"></div>').attr('id', key).click(function () {
            row_content.slideToggle("fast");
        });
        row.append(`<h4 class="headings">process model: <b>${key}</b></h4>`);

        inner_col = $('<div class="col border border-3 border-top-0 border-secondary"></div>');
        row_content.append(inner_col);
        

        console.log('key', key);

        let overall_info_row = $(`<div class="row slider mx-3 my-1 border-bottom-0"></div>`);
        let overall_info_col = $('<div class="col"></div>').html('<h5 class="text-center my-1">Test run Data</h5>');
        let overall_info_content = $('<ul class="list-group list-group-flush text-center"></ul>').html(`<li class="list-group-item"><b>Total tests run:</b> ${data['total']}</li><li class="list-group-item"><b>Test run duration:</b> ${Math.round(data[key]['duration_in_seconds']*100)/100}s</li><li class="list-group-item"><b>Start Service used:</b> ${data['settings']['start']}</li>`);
        overall_info_col.append(overall_info_content);
        overall_info_row.append(overall_info_col);
        inner_col.append(overall_info_row);
        let info_row_testinstances = $(`<div class="row slider mx-3 my-1 border-bottom-0"></div>`);
        let ins_1_info = $('<div class="col"></div>').html('<h5 class="text-center my-1">Instance 1</h5>');
        let ins_1_info_content =  $('<ul class="list-group list-group-flush text-center"</ul>').html(`<li class="list-group-item"><b>Process Engine:</b> ${data['settings']['instance_1']['process_engine']}</li><li class="list-group-item"><b>Execution Handler:</b> ${data['settings']['instance_1']['execution_handler']}</li><li class="list-group-item"><b>Test case duration:</b> ${Math.round(data[key]['instance_1']['duration_in_seconds']*100)/100}s</li>`);
        
        if ('cf_ins_1' in data['results'][key]){
            if (data['results'][key]['cf_ins_1']){
                ins_1_info_content.append(`<li class="list-group-item"><b>Passed Control Flow Check:</b> &#9989;</li>`)
            } else {
                ins_1_info_content.append(`<li class="list-group-item"><b>Passed Control Flow Check:</b> &#10060;</li>`)
            } 
        }
        ins_1_info.append(ins_1_info_content);

        let ins_2_info = $('<div class="col"></div>').html('<h5 class="text-center my-1">Instance 2</h5>');
        let ins_2_info_content =  $('<ul class="list-group list-group-flush text-center"</ul>').html(`<li class="list-group-item"><b>Process Engine:</b> ${data['settings']['instance_2']['process_engine']}</li><li class="list-group-item"><b>Execution Handler:</b> ${data['settings']['instance_2']['execution_handler']}</li><li class="list-group-item"><b>Test case duration:</b> ${Math.round(data[key]['instance_2']['duration_in_seconds']*100)/100}s</li>`)
        if ('cf_ins_2' in data['results'][key]){
            if (data['results'][key]['cf_ins_2']){
                ins_2_info_content.append(`<li class="list-group-item"><b>Passed Control Flow Check:</b> &#9989;</li>`)
            } else {
                ins_2_info_content.append(`<li class="list-group-item"><b>Passed Control Flow Check:</b> &#10060;</li>`)
            } 
        }
        ins_2_info.append(ins_2_info_content);
        info_row_testinstances.append(ins_1_info, ins_2_info);
        inner_col.append(info_row_testinstances);
        let matches_ins_1 = value['matches'][0];
        let matches_ins_2 = value['matches'][1];

        let maxxed = false;
        let index_2 = 0;
        // Generate all for matches from 1 to 2

        for (const [ind_1, ind_2] of Object.entries(matches_ins_1)) {
            // put matching elements here
            let log_match_id = ind_1.toString() + ind_2.toString();
            let inner_row = $(`<div class="row slider mx-3 my-1 border-bottom-0" id=${log_match_id}></div>`);
            let inner_row_panel = $('<div class="row panel mx-3"></div>');
            inner_row.click(function (e) {
                inner_row_panel.slideToggle("fast");
                inner_row_panel.css("display", "flex");
                e.stopPropagation();
            });

            inner_row.append(`<h5 class='headings'>event: <b>${value['log_instance_1'][ind_1]['channel']} </b></h5>`);

            let ins_1_log = $('<div class="col"></div>').html('<h5 class="text-center my-1">Instance 1</h5>');
            let marked = false;
            let json_1 = $('<pre></pre>').text(JSON.stringify((value['log_instance_1'][ind_1]['message']), undefined, 2));
            let marked_content = "";
            if ((Array.isArray(value['structure_differences'][0][ind_1]) && value['structure_differences'][0][ind_1].length)) {
                console.log("detected structure differences");
                marked_content = markInnerStructureResults(json_1.html(), ind_1, value['structure_differences'][0]);
                json_1.html(marked_content);
                marked = true;
            }
            if ((Array.isArray(value['content_differences'][0][ind_1]) && value['content_differences'][0][ind_1].length)) {
                if (marked) {
                    marked_content = markInnerContentResults(marked_content, ind_1, value['content_differences'][0]);
                } else {
                  marked_content = markInnerContentResults(json_1.html(), ind_1, value['content_differences'][0]);
                }
                json_1.html(marked_content);
                marked = true;
                console.log("Current marked value" + marked);
            }
            ins_1_log.append(json_1);
            let ins_2_log = $('<div class="col"></div>').html('<h5 class="text-center my-1">Instance 2</h5>');
            if (ind_2 == "only_ins_1" || ind_2 == "no_match") {
                inner_row.addClass('blue-red-gradient');
                ins_2_log.append(ind_2);
            }
            else if (marked) {
                inner_row.addClass('blue-yellow-gradient');
                json_2 = $('<pre></pre>').text(JSON.stringify(value['log_instance_2'][ind_2]['message'], undefined, 2));
                let marked_content_2 = "";
                let marked_2 = false;
                console.log("In marked if branch");
                console.log("Strukturdifferenz" + value['structure_differences'][1][ind_2]);
                if ((Array.isArray(value['structure_differences'][1][ind_2]) && value['structure_differences'][1][ind_2].length)) {
                    console.log("detected structure differences in second instance log");
                    console.log(value['structure_differences'][1][ind_2]);
                    marked_content_2 = markInnerStructureResults(json_2.html(), ind_2, value['structure_differences'][1]);
                    json_2.html(marked_content_2);
                    marked_2 = true;
                }
                if ((Array.isArray(value['content_differences'][1][ind_2]) && value['content_differences'][1][ind_2].length)) {
                    if (marked_2) {
                        marked_content_2 = markInnerContentResults(marked_content_2, ind_2, value['content_differences'][1]);
                    } else {
                        marked_content_2 = markInnerContentResults(json_2.html(), ind_2, value['content_differences'][1]);
                    }
                    json_2.html(marked_content_2);
                }
                json_2.html(marked_content_2);
                ins_2_log.append(json_2);
            }
            else {
                inner_row.addClass('blue-green-gradient');
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
                let inner_row_panel = $('<div class="row panel mx-3 border-bottom-0 border-primary"></div>');
                inner_row.click(function (e) {
                    inner_row_panel.slideToggle("fast");
                    inner_row_panel.css("display", "flex");
                    e.stopPropagation();
                });
                // put one block [matches_ins_2[index_2]  || ins_2_element ]
                inner_row.append(`<h5 class='headings'>event: <b>${value['log_instance_2'][ind_2]['channel']}</b></h5>`);
                let ins_1_log = $('<div class="col"><h5 class="text-center my-1">Instance 1</h5></div>').append(ind_1);
                let ins_2_log = $('<div class="col"></div>').html('<h5 class="text-center my-1">Instance 2</h5>');
                let json_2 = $('<pre></pre>').text(JSON.stringify(value['log_instance_2'][ind_2]['message'], undefined, 2));
                ins_2_log.append(json_2);
                if (ind_1 == "no_match" || ind_1 == "only_ins_2") {
                    inner_row.addClass('blue-red-gradient');
                }
                inner_row_panel.append(ins_1_log, ins_2_log);
                inner_col.append(inner_row, inner_row_panel);
            }
        }

        $(`#${appendto}`).append(row, row_content);
    })

}

function isXML(filename) {
    fileextension = filename.split(".").pop();

    console.log('file_extension', fileextension);
    if (fileextension != 'xml') {
        return false;
    } else {
        return true;
    }
}
function enableStart() {
    let pe_1 = document.getElementById('pe_1').classList.contains('is-invalid');
    let pe_2 = document.getElementById('pe_2').classList.contains('is-invalid');
    let stas = document.getElementById('start_service').classList.contains('is-invalid');
    let file = document.getElementById('file_input').classList.contains('is-invalid');
    console.log('in enable start');
    console.log('values : ', pe_1, pe_2, stas);
    if ((pe_1 || pe_2 || stas || file)) {
        console.log("in first if");
        $('#start').prop('disabled', true);
    } else {
        console.log("in else");
        $('#start').prop('disabled', false);
    }
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
        for (let type in data['tests']) {
            let opt_group_target;
            if (type == "aalst") {
                opt_group_target = 'allstopt';
            } else if (type == "cpee") {
                opt_group_target = 'cpeeopt'
            }
            for (let test_case in data['tests'][type]) {
                let item = data['tests'][type][test_case];
                $('#' + opt_group_target).append($(new Option(item["name"], item['name'])));
            }
        };
        $('#start').removeAttr('disabled');
    });

    $('#new_result').hide();
    // get previous results
    $.ajax({
        url: run_tests_url,
        type: 'GET'
    }).done(function (data) {
        if (data != null) {
            console.log("made get request for prev data");
            jQuery.each(data, function (key, value) {
                let row_content = $('<div class="row justify-content-center panel mx-5"></div>').attr('id', "testcase-" + key);
                let row = $('<div class="row slider mx-5 mt-3"></div>').attr('id', key).click(function () {
                    row_content.slideToggle("fast");
                });
                row.append(`<h4 class="headings">Test ${key}</h4>`);
                inner_col = $(`<div id='col-${key}' class="col border border-3 border-top-0 border-secondary"></div>`);
                row_content.append(inner_col);
                let col_id = "col-" + key
                displayResults(value, col_id);
                $('#results').append(row, row_content);
            })
        }
    });

    target = "";
    if ($("#pe_1").val().length == 0) {
        target = $("#pe_1").attr('placeholder');
    }
    else {
        target = $("#pe_1").val();
    }
    $.ajax({
        url: target + "executionhandlers/",
        type: 'GET',
        dataType: 'xml',
        error: function (request, status, error) {
            $('#pe_1').addClass('is-invalid');
            $('#start').prop('disabled', true);
        },
        success: function () {
            $('#start').prop('disabled', false);
            $('#pe_1').removeClass('is-invalid');
            $('#pe_1').addClass('is-valid');
        }
    }).done(function (data) {
        $(data).find('handler').each(function () {
            if ($(this).text() != 'eval') {
            $('#exe1').append('<option class="exe1" value="' + $(this).text() + '">' + $(this).text() + '</option>');
            }
        })
    });


    target = "";
    if ($("#pe_2").val().length == 0) {
        target = $("#pe_2").attr('placeholder');
    }
    else {
        target = $("#pe_2").val();
    }
    $.ajax({
        url: target + "executionhandlers/",
        type: 'GET',
        dataType: 'xml',
        error: function (request, status, error) {
            $('#pe_2').addClass('is-invalid');
            $('#start').prop('disabled', true);
        },
        success: function () {
            $('#start').removeAttr('disabled');
            $('#pe_2').removeClass('is-invalid');
            $('#pe_2').addClass('is-valid');
        }
    }).done(function (data) {
        $(data).find('handler').each(function () {
            if ($(this).text() != 'eval') {
                $('#exe2').append('<option class="exe2" value="' + $(this).text() + '">' + $(this).text() + '</option>');
                }
        })
    });

    let url = new RegExp('^https?:\/\/[a-z]+\.[a-z]+(\/[a-z]+)*\/?');
    let start_service = $('#start_service').val();
    if (start_service.length == 0) {
      start_service = $('#start_service').attr('placeholder');
    }
    if (url.test(start_service)) {
       $('#start_service').removeClass('is-invalid');
        enableStart();
    } else {
      $('#start_service').addClass('is-invalid');
       enableStart();
    }

    $('#start_service').focus(function () {
      $('#start_service').removeClass('is-invalid');
      enableStart();
    });
    
    $('#start_service').blur(function () {
      let url = new RegExp('^https?:\/\/[a-z]+\.[a-z]+(\/[a-z]+)*\/?')
      let start_service = $('#start_service').val();
      if (start_service.length == 0) {
         start_service = $('#start_service').attr('placeholder');
        }
      if (url.test(start_service)) {
        $('#start_service').removeClass('is-invalid');
        enableStart();
        } else {
          $('#start_service').addClass('is-invalid');
          enableStart();
        }
    });


    $('#pe_1').focus(function () {
        $('#pe_1').removeClass('is-valid');
        $('.exe1').each(function () {
            $(this).remove();
        })
    });

    $("#pe_1").blur(function () {
        if ($("#pe_1").val().length == 0) {
            target = $("#pe_1").attr('placeholder');
        }
        else {
            target = $("#pe_1").val();
        }
        $.ajax({
            url: target + "executionhandlers/",
            type: 'GET',
            dataType: 'xml',
            error: function (request, status, error) {
                $('#pe_1').addClass('is-invalid');
                enableStart();
            },
            success: function () {
                $('#pe_1').removeClass('is-invalid');
                enableStart();
                $('#pe_1').addClass('is-valid');
            }
        }).done(function (data) {
            $(data).find('handler').each(function () {
                $('#exe1').append('<option class="exe1" value="' + $(this).text() + '">' + $(this).text() + '</option>');
            })
        });
    });
    $('#pe_2').focus(function () {
        $('#pe_2').removeClass('is-valid');
        $('.exe2').each(function () {
            $(this).remove();
        })
    });
    $("#pe_2").blur(function () {
        if ($("#pe_2").val().length == 0) {
            target = $("#pe_2").attr('placeholder');
        }
        else {
            target = $("#pe_2").val();
        }
        console.log("Value of input field: " + target)
        $.ajax({
            url: target + "executionhandlers/",
            type: 'GET',
            dataType: 'xml',
            error: function (request, status, error) {
                $('#pe_2').addClass('is-invalid');
                enableStart();
            },
            success: function () {
                $('#pe_2').removeClass('is-invalid');
                enableStart();
                $('#pe_2').addClass('is-valid');
            }
        }).done(function (data) {
            $(data).find('handler').each(function () {
                $('#exe2').append('<option class="exe2" value="' + $(this).text() + '">' + $(this).text() + '</option>');
            })
        });
    });


    if ($('#fixed_file').is(':checked')) {
        $('#upload').hide();
        $('#tests').show();
        $("#start").prop('disabled', false);
    } else if ($('#own_file').is(':checked')) {
        $('#tests').hide();
        $('#upload').show();
        let filename = document.getElementById('file_input').files[0].name;
        if (document.getElementById('file_input').files.length == 0 || !isXML(filename)) {
            $('#file_input').addClass('is-invalid');
            enableStart();
            $('#upload').append('<p id="file-error" class="error-text">Only XML file allowed!</p>');
        } else {
            $('#file_input').removeClass('is-invalid');
            enableStart();
            $('#file-error').remove();
        }
    }



    $('#fixed_file').click(function () {
        $('#upload').hide();
        $('#tests').show();
        enableStart();
    });

    $('#own_file').click(function () {
        $('#tests').hide();
        $('#upload').show();
        enableStart();
    });



    $('#file_input').change(function () {
        let filename = document.getElementById('file_input').files[0].name;
        console.log(filename);
        if (document.getElementById('file_input').files.length == 0 || !isXML(filename)) {
            $('#file_input').addClass('is-invalid');
            enableStart();
            $('#upload').append('<p id="file-error" class="error-text">Only XML file allowed!</p>');
        } else {
            console.log($("#file_input").prop('files')[0]);
            $('#file_input').removeClass('is-invalid');
            enableStart();
            $('#file-error').remove();
        }
    });

    $("#start").click(function () {

        var data = new FormData();
        let target_1 = '';
        let target_2 = '';
        let start_service = '';
        if ($("#pe_1").val().length == 0) {
            target_1 = $("#pe_1").attr('placeholder');
        } else {
            target_1 = $("#pe_1").val();
        }
        if ($("#pe_2").val().length == 0) {
            target_2 = $("#pe_2").attr('placeholder');
        } else {
            target_2 = $("#pe_2").val();
        }
        if ($("#start_service").val().length == 0) {
            start_service = $("#start_service").attr('placeholder');
        } else {
            start_service = $("#start_service").val();
        }
        let model = null;
        if (($('#fixed_file').is(':checked'))) {
            test_name = $("#test_case").val();
        } else {
            test_name = $("#file_input").prop('files')[0].name;
            own_model_provided = true;
            model = $("#file_input").prop('files')[0];
        }
        const form_data = {
            start: start_service,
            instance_1: { process_engine: target_1, execution_handler: $("#exe1").val() },
            instance_2: { process_engine: target_2, execution_handler: $("#exe2").val() },
            test: test_name
        };
        $("#main").remove();
        $("#results").remove();
        $("#overlay").fadeIn(300);
        settings = JSON.stringify(form_data);
        settings = new Blob([settings], {
            type: 'application/json'
        });
        data.append("settings", settings);
        console.log(settings);
        if (model != null) {
            data.append("model", model)
            console.log(typeof model);
        }
        $.ajax({
            url: run_tests_url,
            type: 'POST',
            data: data,
            contentType: false,
            processData: false,
            headers: { 'Content-ID': 'test-config' }
        }).done(function (data) {
            let res = getResult(run_tests_url, data);
            displayResults(res, 'new_result');
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
        if ((res == null || res["status"] !== "finished")) { await delay(500); }
    } while (res == null || res["status"] !== "finished");
    $('#new_result').show();
    return res;
}

function delay(t) {
    return new Promise(resolve => {
        setTimeout(resolve, t);
    });
}
