jQuery(function ($) {
    $(document).ajaxSend(function () {
        $("#overlay").fadeIn(300);
    });
});
function displayResults( data ){
    
}
$(document).ready(function () {

    /* 
     let config_url = "http://localhost:9303/configuration/";
     let run_tests_url = "http://localhost:9303/fulltest/";
 
     $.getJSON(config_url, function(data){
         for (let index in data["process_engines"]) {
             let item = data["process_engines"][index]
             console.log(item);
             ($('select[name="process-engine-form"]')).append($(new Option(item["name"], item["url"])));
         };
         for (let index in data['execution_handlers']) {
             let item = data['execution_handlers'][index];
             console.log(item);
             ($('select[name="executionhandler"]')).append($(new Option(item, item)));
         };
         for (let index in data['tests']) {
             let item = data['tests'][index];
             console.log(item);
             ($('#test_case')).append($(new Option(item['name'], [item['ruby'], item['rust']])));
         };
         });
         */

    $("#start").click(function () {
        $("#main").remove();
        let form_data = {
            "instance_1": [
                { "process_engine": $("#cpee1").val() },
                { "execution_handler": $("#exe1").val() }],
            "instance_2": [
                { "process_engine": $("#cpee2").val() },
                { "execution_handler": $("#exe2").val() }],
            "test": $("#test_case").val()
        };
        $.ajax({
            url: "http://localhost:9303/fulltest/",
            type: 'POST',
            data: form_data,
            dataType: 'json',
            success: function(data) {
                let ins =  data["instance"];
            }
        });
        $.ajax({
            url: "http://localhost:9303/fulltest/" + ins,
            type: 'GET',
            dataType: 'json',
            success: function(data) {
                console.log(data);
            }
        }).done(function () {
            setTimeout(function () {
                $("#overlay").fadeOut(300);
            }, 500);
            displayResults(data);
        });
    });
});