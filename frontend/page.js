
$(document).ready(function(){

    let url = "https://echo.bpm.in.tum.de/fulltest/configuration";
    // let url = "localhost:9303/fulltest/configuration";
    $.getJSON(url, function(data){
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


    
    

});