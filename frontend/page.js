
$(document).ready(function(){

    let url = "https://echo.bpm.in.tum.de/fulltest/configuration";
    // let url = "localhost:9303/fulltest/configuration";
    $.getJSON(url, function(data){
        console.log(data);
        console.log(data["process_engines"])
        for (let index in data["process_engines"]) {
            let item = data["process_engines"][index]
            console.log(item);
            ($('select[name="process-engine-form"]')).append($(new Option(item["name"], item["url"])));
        };

    });

    
    
    

});