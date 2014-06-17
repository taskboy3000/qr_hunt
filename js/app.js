// Models
UserModel = Backbone.Model.extend(
{
    urlRoot: "/api/1.0/user",
    defaults: 
    {
        screen_name: "",
        twitter_id: "",
    }
});

// Collection
UserList = Backbone.Collection.extend(
{
        model: UserModel,
        url: "/api/1.0/user",
});

// Views
var ItemView = Backbone.View.extend(
  {
        tagName: "li",
        initialize: function()
        {
           
        },

        events: 
        {
          'click [data-role=delete]' : 'handle_delete',
          'click [data-role=edit]' : 'handle_edit',
        },
        
        handle_delete: function(e)
        {
                var id = this.$el.find("button[data-role=delete]").attr("data-id");
                alert("delete: " + id);  
        },
        
        handle_edit: function(e)
        {
            var id = this.$el.find("button[data-role=edit]").attr("data-id");
            var thisUserModel = this.model; // current model

            // Create the view     
            var thisEditView = new EditView({ model: thisUserModel });
            console.log("Rending editView");
            thisEditView.render();
        },

        template: _.template($("#user-template").html()),
        
        render: function()
        {
          $(this.el).html(this.template(this.model.toJSON()));
          return this;
        }
  });

ListView = Backbone.View.extend(
  {
        el: "#user-list",

        initialize: function()
        {
           _.bindAll(this, 'render', 'appendItem');

           console.log("New list");
           this.collection = new UserList();

           this.collection.bind('add', this.appendItem);
           var self = this;
           // will fire off 'add' events, which we bind to the
           // view's appendItem() function.
           this.collection.fetch({success: function(){console.log("Fetched");}});   
        },
        
        render: function()
        {
          
          console.log("start listview render");
          var self = this; // point to the correct object in .each() below
          console.log(this.collection.models);
          _(this.collection.models).each(function(item)
          {
            self.appendItem(item);
          }, this);
        },

        appendItem: function(item)
        {
           console.log("creating new itemview: " + item.get("name"));
           var itemView = new ItemView(
           {
             model: item
           });
           // remember, that we bound 'this' in the view initialized
           $(this.el).append(itemView.render().el);
        }

  });

  var thisListView = new ListView();
