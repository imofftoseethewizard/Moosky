//=============================================================================
//
//
// This file is part of Moosky.
//
// Moosky is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Moosky is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Moosky.  If not, see <http://www.gnu.org/licenses/>.
//
//
//=============================================================================

Moosky.Tools = (
    function () {
        function Template(templ) {
            this.$templ = templ;
            this.$regexps = {};
            const matches = templ.match(/<<(\w|\d)+>>/g) || [];
            for (var i = 0; i < matches.length; i++) {
                const pattern = matches[i];
                this.$regexps[pattern.slice(2, -2)] = new RegExp(pattern, 'g');
            }
        }

        Template.prototype.fill = function(params) {
            var text = this.$templ;
            for (var p in params) {
                if (this.$regexps[p])
	            text = text.replace(this.$regexps[p], function() { return params[p]; });
            }

            return text;
        };

        function RecursiveTemplate(base, pattern) {
            this.base = base;
            this.pattern = pattern;
        }

        RecursiveTemplate.prototype.initialize = function() {
            this.base = new Template(this.base);

            const pattern = this.pattern;

            const next = pattern.match(this.nextRe);
            const prior = pattern.match(this.priorRe);

            console.log(next.index);
            if (!next || !prior)
                throw RecursiveTemplate.DefinitionError(this.definitionErrorMessage);

            const nextRe = new RegExp("(.{" + next.index + "})(.{" + this.nextSubstLength + "})");
            const priorRe = new RegExp("(.{" + prior.index + "})(.{" + this.priorSubstLength + "})");

            const nextTarget = { re: nextRe,
		                 label: this.nextLabel };

            const priorTarget = { re: priorRe,
			          label: this.priorLabel };

            this.targets = [];
            if (next.index < prior.index) {
                this.targets[0] = priorTarget;
                this.targets[1] = nextTarget;
            }
            else {
                this.targets[0] = nextTarget;
                this.targets[1] = priorTarget;
            }
        };

        RecursiveTemplate.DefinitionError = function(message) {
            this.message = message;
        };

        RecursiveTemplate.DefinitionError.prototype = new Error();
        RecursiveTemplate.DefinitionError.prototype.name = 'RecursiveTemplate.DefinitionError';

        RecursiveTemplate.prototype.fill = function(params) {
            const baseParamIndex = this.getBaseParamIndex(params);
            var result = this.base.fill([params[baseParamIndex]]);

            params = this.orderParams(params);
            for (var i = 0, length = params.length; i < length; i++) {
                const values = [];
                values[this.priorLabel] = result;
                values[this.nextLabel] = params[i];

                var intermediate = this.pattern;
                for (var j = 0; j < 2; j++) {
	            const target = this.targets[j];
	            intermediate = intermediate.replace(target.re, '$1' + values[target.label]);
                }

                result = intermediate;
            }

            return result;
        };

        function RightRecursiveTemplate(base, pattern) {
            RecursiveTemplate.call(this, base, pattern);
            this.initialize();
        }

        RightRecursiveTemplate.prototype = new RecursiveTemplate();

        RightRecursiveTemplate.prototype.baseRe = /<<n>>/;
        RightRecursiveTemplate.prototype.nextRe = /<<i>>/;
        RightRecursiveTemplate.prototype.priorRe = /<<\.\.\.n>>/;

        RightRecursiveTemplate.prototype.nextLabel = 'i';
        RightRecursiveTemplate.prototype.priorLabel = '...n';

        RightRecursiveTemplate.prototype.nextSubstLength = 5;
        RightRecursiveTemplate.prototype.priorSubstLength = 8;

        RightRecursiveTemplate.prototype.definitionErrorMessage = 'Both <<i>> and '
            + '<<...n>> template parameters must exist in the template definition '
            + 'string.';

        RightRecursiveTemplate.prototype.getBaseParamIndex = function(params) {
            return 0;
        };

        RightRecursiveTemplate.prototype.orderParams = function(params) {
            const indices = [];
            for (var i = 1, length = params.length; i < length; i++)
                indices.push(params[i]);
            return indices;
        };

        function LeftRecursiveTemplate(base, pattern) {
            RecursiveTemplate.call(this, base, pattern);
            this.initialize();
        }

        LeftRecursiveTemplate.prototype = new RecursiveTemplate();

        LeftRecursiveTemplate.prototype.baseRe = /<<1>>/;
        LeftRecursiveTemplate.prototype.nextRe = /<<n>>/;
        LeftRecursiveTemplate.prototype.priorRe = /<<1\.\.\.>>/;

        LeftRecursiveTemplate.prototype.nextLabel = 'n';
        LeftRecursiveTemplate.prototype.priorLabel = '1...';

        LeftRecursiveTemplate.prototype.nextSubstLength = 5;
        LeftRecursiveTemplate.prototype.priorSubstLength = 8;

        LeftRecursiveTemplate.prototype.definitionErrorMessage = 'Both <<1...>> and '
            + '<<n>> template parameters must exist in the template definition '
            + 'string.';

        LeftRecursiveTemplate.prototype.getBaseParamIndex = function(params) {
            return params.length-1;
        };

        LeftRecursiveTemplate.prototype.orderParams = function(params) {
            const indices = [];
            for (var i = params.length-2; i >= 0; i--)
                indices.push(params[i]);
            return indices;
        };

        function InlineTemplate(patterns) {
            this.subTemplates = [];

            for (var p in patterns) {
                const template = InlineTemplate.createTemplate(patterns[p], patterns);
                InlineTemplate.assertSubTemplateWellFormed(p, template);
                this.subTemplates[p] = template;
            }
        }

        InlineTemplate.createTemplate = function(pattern, patterns) {
            const matches = pattern.match(/<<(\w|\.)+>>/g) || [];
            for (var i = 0; i < matches.length; i++) {
                const target = matches[i].slice(2, -2);
                if (target == '1...')
	            return new LeftRecursiveTemplate(patterns[1], pattern);

                if (target == '...n')
	            return new RightRecursiveTemplate(patterns[1], pattern);
            }
            return new Template(pattern);
        };

        InlineTemplate.assertSubTemplateWellFormed = function(label, template) {
            if (label.match(/^\d$/)) {
                for (var i = 0, limit = parseInt(label)-1; i < limit; i++)
	            if (template.$regexps[i] === undefined)
	                throw new InlineTemplate.DefinitionError('Template for the ' + label +
	                                                         ' parameter case does not define all template parameters from '
	                                                         + '<<0>> to <<' + limit + '>>: <<' + i + '>> is missing.');

            }
        };

        InlineTemplate.DefinitionError = function(message) {
            this.message = message;
        };

        InlineTemplate.DefinitionError.prototype = new Error();
        InlineTemplate.DefinitionError.prototype.name = 'InlineTemplate.DefinitionError';

        InlineTemplate.ExpansionError = function(message) {
            this.message = message;
        };

        InlineTemplate.ExpansionError.prototype = new Error();
        InlineTemplate.ExpansionError.prototype.name = 'InlineTemplate.ExpansionError';

        InlineTemplate.prototype.fill = function(params) {
            const template = this.subTemplates[params.length]
		  || this.subTemplates['1...']
		  || this.subTemplates['...n'];

            if (template === undefined)
                throw new InlineTemplate.ExpansionError('Too many parameters for any ' +
	                                                'fixed-length case, and there is no recursive case.');

            return template.fill(params);
        };

        return { Template: Template,
	         RightRecursiveTemplate: RightRecursiveTemplate,
	         LeftRecursiveTemplate: LeftRecursiveTemplate,
	         InlineTemplate: InlineTemplate };
    }
)();
