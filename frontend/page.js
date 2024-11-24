
$(document).ready(function(){

    const processEngines = ['echo', 'demo']
    
    var $forms = $('select[name="process-engine-form"]');
    console.log($forms)
    
    processEngines.forEach(addOptions) 
    

    function addOptions(item, index, arr) {
        ($('select[name="process-engine-form"]')).append($(new Option(item, index)));
    }
    

});