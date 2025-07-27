/**
* Created by chynajake on 2/1/18.
*/

yourlabs.Autocomplete.prototype.fixPosition = function(html) {
    this.input.parents().filter(function() {
        return $(this).css('overflow') === 'hidden';
    }).first().css('overflow', 'visible');

    this.box.insertAfter(this.input).css({top: 0, left: 0});
};