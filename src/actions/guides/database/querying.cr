class Guides::Database::Querying < GuideAction
  ANCHOR_PRELOADING     = "perma-preloading"
  ANCHOR_RELOADING      = "perma-reloading"
  ANCHOR_QUERYING_ENUMS = "perma-querying-enums"
  guide_route "/database/querying-records"

  def self.title
    "Querying records"
  end

  def markdown : String
    <<-MD
    ## Query Objects

    When you [generate a model](#{Guides::Database::Models.path(anchor: Guides::Database::Models::ANCHOR_GENERATE_A_MODEL)}),
    Avram will create a Query class for you in `./src/queries/{model_name}_query.cr`.
    This class will inherit from `{ModelName}::BaseQuery`. (e.g. with a `User` model you get
    a `User::BaseQuery` class).

    ```crystal
    # src/queries/user_query.cr
    class UserQuery < User::BaseQuery
    end
    ```

    Each column defined on the model will also generate methods for the query object to use.
    This gives us a type-safe way to query on each column. All of the query methods are chainable
    for both simple and more complex queries.

    ## Running Queries

    When you run any query, Avram will return an instance, array of instances, `nil`, or
    raise an exception (e.g. `Avram::RecordNotFoundError`).

    For our examples, we will use this `User` model.

    ```crystal
    class User < BaseModel
      table :users do
        # `id`, `created_at`, and `updated_at` are predefined for us
        column name : String
        column age : Int32
        column admin : Bool

        has_many tasks : Task
      end
    end
    ```

    ### Select shortcuts

    By default, all query objects include the `Enumerable(T)` module, which means methods
    like `each`, and `map` may be used.

    All query methods are called on the instance of the query object, but there's also a
    few class methods for doing quick finds.

    * `first` - Returns the first record. Raise `Avram::RecordNotFoundError` if no record is found.
    * `first?` - Returns the first record. Returns `nil` if no record is found.
    * `find(id)` - Returns the record with the primary key `id`. Raise `Avram::RecordNotFoundError` if no record is found.
    * `last` - Returns the last record. Raise `Avram::RecordNotFoundError` if no record is found.
    * `last?` - Returns the last record. Returns `nil` if no record is found.

    ```crystal
    first_user = UserQuery.first
    last_user = UserQuery.last
    specific_user = UserQuery.find(4)
    all_users = UserQuery.new
    ```

    > The `find` method requires a `primary_key`. `view` models that need this method will need to implement it.

    ### Lazy loading

    The query does not actually hit the database until a method is called to fetch a result
    or iterate over results.

    The most common methods are:

    * `first`
    * `find`
    * `each`

    For example:

    ```crystal
    # The query is not yet run
    query = UserQuery.new.name("Sally").age(30)

    # The query will run once `each` is called
    # Results are not cached so a request will be made every time you call `each`
    query.each do |user|
      pp user.name
    end
    ```

    ### Immutability

    Queries are immutable. Whenever a method is called on a query, it returns a new copy
    of itself with the condition added. The query the method was called on will not be changed.

    ```crystal
    query = UserQuery.new.name("Wendy")
    new_query = query.age(40)

    query.to_sql     #=> SELECT COLUMNS FROM users WHERE users.name = 'Wendy';
    new_query.to_sql #=> SELECT COLUMNS FROM users WHERE users.name = 'Wendy' AND users.age = 40;
    ```

    ## Simple Selects

    > When doing a `SELECT`, Avram will select all of the columns individually (i.e. `users.id,
    > users.created_at, users.updated_at, users.name, users.age, users.admin`) as opposed to `*`.
    > However, for brevity, we will use `COLUMNS`.

    ### Select all

    `SELECT COLUMNS FROM users`

    ```crystal
    users = UserQuery.new
    ```

    ### Select first

    `SELECT COLUMNS FROM users ORDER BY users.id ASC LIMIT 1`

    ```crystal
    # raise Avram::RecordNotFound if nil
    user = UserQuery.new.first

    # returns nil if not found
    user = UserQuery.new.first?
    ```

    ### Select last

    `SELECT COLUMNS FROM users ORDER BY users.id DESC LIMIT 1`

    ```crystal
    # raise Avram::RecordNotFound if nil
    user = UserQuery.new.last

    # returns nil if not found
    user = UserQuery.new.last?
    ```

    ### Select by primary key

    Selecting the user with `id = 3`.
    `SELECT COLUMNS FROM users WHERE users.id = 3 LIMIT 1`

    ```crystal
    # raise Avram::RecordNotFound if nil
    user = UserQuery.new.find(3)
    ```

    ### Select distinct / distinct on

    `SELECT DISTINCT COLUMNS FROM users`

    ```crystal
    UserQuery.new.distinct
    ```

    Select distinct rows based on the `name` column `SELECT DISTINCT ON (users.name) FROM users`

    ```crystal
    UserQuery.new.distinct_on(&.name)
    ```

    ## Where Queries

    The `WHERE` clauses are the most common used in SQL. Each of the columns generated by the model
    will give you a method for running a `WHERE` on that column. (e.g. the `age` can be queried using
    `age(30)` which produces the SQL `WHERE age = 30`).

    ### A = B

    Find rows where `A` is equal to `B`.

    `SELECT COLUMNS FROM users WHERE users.age = 54`

    ```crystal
    UserQuery.new.age(54)
    ```

    In some cases, the value you pass in may be nilable. If you pass in a `nil` value,
    Avram will raise an exception.

    For these cases, you would use the `nilable_eq` method.

    ```crystal
    UserQuery.new.age.nilable_eq(potential_age_or_nil_value)
    ```

    ### WHERE with AND (A = B AND C = D)

    Find rows where `A` is equal to `B` and `C` is equal to `D`.

    `SELECT COLUMNS FROM users WHERE users.age = 43 AND users.admin = true`

    ```crystal
    UserQuery.new.age(43).admin(true)
    ```

    > All query methods are chainable!

    ### WHERE with OR (A = B OR A = C)

    Find rows where `A` is equal to `B` or `A` is equal to `C`.

    `SELECT COLUMNS FROM users WHERE users.name = 'Alfred' OR users.name = 'Bruce'`

    ```crystal
    UserQuery.new.name("Alfred").or(&.name("Bruce"))
    ```

    `OR` queries can become quite complex. If you need to wrap conditions, you can use
    the `where(&)` method. This will take a block, and wrap any query chain inside with
    parenthesis `()`.

    `SELECT COLUMNS FROM users WHERE users.likes_bats = true OR (users.first_name = 'Kate' AND users.last_name = 'Kane')`

    ```crystal
    UserQuery.new.likes_bats(true).or do |or|
      or.where do |where|
        where.first_name("Kate").last_name("Kane"))
      end
    end
    ```

    ### A != B

    Find rows where `A` is not equal to `B`.

    `SELECT COLUMNS FROM users WHERE users.name != 'Billy'`

    ```crystal
    UserQuery.new.name.not.eq("Billy")
    ```

    > The `not` method can be used to negate other methods like `eq`, `gt`, `lt`, and `in`.

    ### A IS NULL / IS NOT NULL

    Find rows where `A` is `nil` using is_nil.

    `SELECT COLUMNS FROM users WHERE users.name IS NULL`

    ```crystal
    UserQuery.new.name.is_nil
    ```

    Find rows where `A` is *not* `nil`.

    `SELECT COLUMNS FROM users WHERE users.name IS NOT NULL`

    ```crystal
    UserQuery.new.name.is_not_nil
    ```

    ### LOWER/UPPER A = B

    Find rows where (casting `A` to LOWER/UPPER) is equal to `B`

    `SELECT COLUMNS FROM users WHERE LOWER(users.name) = 'gar'`

    ```crystal
    UserQuery.new.name.lower.eq("gar")
    ```

    `SELECT COLUMNS FROM users WHERE UPPER(users.name) = 'GAR'`

    ```crystal
    UserQuery.new.name.upper.eq("GAR")
    ```

    ### A gt/lt B

    * gt: >
    * gte: >=
    * lt: <
    * lte: <=

    Find rows where `A` is greater than or equal to (>=) `B`.

    `WHERE users.age >= 21`

    ```crystal
    UserQuery.new.age.gte(21)
    ```

    Find rows where `A` is greater than `B`.

    `WHERE users.created_at > '#{1.day.ago}'`

    ```crystal
    UserQuery.new.created_at.gt(1.day.ago)
    ```

    Find rows where `A` is less than or equal to `B`.

    `WHERE users.age <= 12`

    ```crystal
    UserQuery.new.age.lte(12)
    ```

    Find rows where `A` is less than `B`.

    `WHERE users.updated_at < '#{3.months.ago}'`

    ```crystal
    UserQuery.new.updated_at.lt(3.months.ago)
    ```

    ### A between C and D

    Find rows where `A` is between `C` and `D`.

    `WHERE users.updated_at >= '#{3.days.ago}' AND users.updated_at <= '#{1.day.ago}'`

    ```crystal
    UserQuery.new.updated_at.between(3.days.ago, 1.day.ago)
    ```

    ### A in / not in (B)

    Find rows where `A` is in the list `B`.

    `WHERE users.name IN ('Bill', 'John')`

    ```crystal
    UserQuery.new.name.in(["Bill", "John"])
    ```

    Find rows where `A` is not in the list `B`.

    `WHERE users.name NOT IN ('Sally', 'Jenny')`

    ```crystal
    UserQuery.new.name.not.in(["Sally", "Jenny"])
    ```

    ### A = ANY of B

    Find rows where `A` is in the array `B`

    `WHERE 'Gold' = ANY (users.badges)`

    ```crystal
    UserQuery.new.badges.includes("Gold")
    ```

    ### A like / iLike B

    Find rows where `A` is like (begins with) `B`.

    `WHERE users.name LIKE 'John%'`

    ```crystal
    UserQuery.new.name.like("John%")
    ```

    `WHERE users.name ILIKE 'jim'`

    ```crystal
    UserQuery.new.name.ilike("jim")
    ```

    #{permalink(ANCHOR_QUERYING_ENUMS)}
    ### Querying enums

    ```crystal
    class User < BaseModel
      enum Role
        Basic
        Admin
      end

      #...
    end
    ```

    ```crystal
    UserQuery.new.role(User::Role::Admin)
    ```

    ### Any? / None?

    When you only need to know if there's any records that match your query
    you can use the `any?` method.

    ```crystal
    # returns `true` if there's at least 1 record
    UserQuery.new.any?
    ```

    The opposite is `none?` which will return `true` if there's no records that
    match your query.

    ```crystal
    # returns `true` if there's no records
    UserQuery.new.none?
    ```

    ## Order By

    Return rows ordered by the `age` column in descending (or ascending) order.

    `SELECT COLUMNS FROM users ORDER BY users.age DESC`

    ```crystal
    UserQuery.new.age.desc_order
    # or for asc order
    UserQuery.new.age.asc_order
    ```

    ### NULLS FIRST / LAST

    Sort records placing NULL values first or last

    `SELECT COLUMNS FROM users ORDER BY users.age DESC NULLS FIRST`

    ```crystal
    UserQuery.new.age.desc_order(:nulls_first)
    # Also sort with NULLS LAST
    UserQuery.new.age.desc_order(:nulls_last)
    ```

    ## Group By

    Return rows grouped by the `age` column.

    `SELECT COLUMNS FROM users GROUP BY users.age, users.id`

    ```crystal
    UserQuery.new.group(&.age).group(&.id)
    ```

    > Using the Postgres GROUP BY function can be confusing. Read more on [postgres aggregate functions](https://www.postgresql.org/docs/current/tutorial-agg.html).

    ## Pagination

    This section has been moved to its own [pagination guide](#{Guides::Database::Pagination.path}).

    ## Aggregate Functions

    ### Select Count

    `SELECT COUNT(*) FROM users`

    ```crystal
    # This will return an Int64.
    # The value will be 0 if there are no records.
    UserQuery.new.select_count
    ```

    ### Select Average / Sum

    `SELECT AVG(users.age) FROM users`

    ```crystal
    # This will return a Float64 | Nil.
    # The value will be nil if there are no records.
    UserQuery.new.age.select_average

    # This will return a Float64.
    # The value will be 0 if there are no records.
    UserQuery.new.age.select_average!
    ```

    `SELECT SUM(users.age) FROM users`

    ```crystal
    # Returns an Int64 for integer columns, or a Float64 for float columns
    # Returns nil if there are no records
    UserQuery.new.age.select_sum

    # Returns an Int64 for integer columns, or a Float64 for float columns
    # Returns 0 if there are no records
    UserQuery.new.age.select_sum!
    ```

    ### Select Min / Max

    `SELECT MIN(users.age) FROM users`

    ```crystal
    UserQuery.new.age.select_min
    ```

    `SELECT MAX(users.age) FROM users`

    ```crystal
    UserQuery.new.age.select_max
    ```

    `select_min` and `select_max` will return a union type of the column and `Nil`.
    For example, if the column type is an `Int32` the return type will be `Int32 | Nil`.


    ## Associations and Joins

    When you have a model that is associated to another, your association is a method you can use
    to return those records.

    ### Associations

    Each association defined on your model will have a method prefixed with `where_` that takes a
    query from the association. This method will add an inner join for you.

    You can use this to help refine your association.

    ```crystal
    # SELECT COLUMNS FROM users INNER JOIN tasks ON users.id = tasks.user_id WHERE tasks.title = 'Clean up notes'
    UserQuery.new.where_tasks(TaskQuery.new.title("Clean up notes"))
    ```

    This will return all users who have a task with a title "Clean up notes".
    You can continue to scope this on both the `User` and `Task` side.

    > This example shows the `has_many` association, but all associations including `has_one`, and
    > `belongs_to` use the same format.


    ### Joins

    By default, using the `where_` methods will use `INNER JOIN`, but you have the option
    to configure this by passing `false` to the `auto_inner_join` argument, and specifying
    a different join method.

    ```crystal
    UserQuery.new
      .left_join_tasks
      .where_tasks(
        TaskQuery.new.title("Clean up notes"),
        auto_inner_join: false)
    ```

    ### Inner joins

    `SELECT COLUMNS FROM users INNER JOIN tasks ON users.id = tasks.user_id`

    ```crystal
    UserQuery.new.join_tasks
    ```

    > By default the `join_{{association_name}}` method will be an `INNER JOIN`, but you can also
    > use `inner_join_{{association_name}}` for clarity

    ### Left joins

    `SELECT COLUMNS FROM users LEFT JOIN tasks ON users.id = tasks.user_id`

    ```crystal
    UserQuery.new.left_join_tasks
    ```

    ### Right joins

    `SELECT COLUMNS FROM users RIGHT JOIN tasks ON users.id = tasks.user_id`

    ```crystal
    UserQuery.new.right_join_tasks
    ```

    ### Full joins

    `SELECT COLUMNS FROM users FULL JOIN tasks ON users.id = tasks.user_id`

    ```crystal
    UserQuery.new.full_join_tasks
    ```

    #{permalink(ANCHOR_PRELOADING)}
    ## Preloading

    In development and test environments Lucky requires preloading associations. If you forget to preload an
    association, a runtime error will be raised when you try to access it. In production, the association will
    be lazy loaded so that users do not see errors.

    This solution means you will find N+1 queries as you develop instead of in production and users will never
    see an error.

    To preload, just call `preload_{association name}` on the query:

    ```crystal
    UserQuery.new.preload_tasks
    ```

    ### Customizing how associations are preloaded

    Sometimes you want to order preloads, or add where clauses. To do this, use the
    `preload_{{association_name }}` method on the query, and pass a query object for the association.

    ```crystal
    UserQuery.new.preload_tasks(TaskQuery.new.completed(false))
    ```

    This is also how you would do nested preloads:

    ```crystal
    # Preload the user's tasks, and the task's author
    UserQuery.new.preload_tasks(TaskQuery.new.preload_author)
    ```

    > Note that you can only pass query objects to `preload` if the association is defined, otherwise you will
    > get a type error.

    ### With existing records

    There are situations where you have an existing record and it does not have the associations preloaded that are needed.
    Instead of loading the association separately, you can add an association after the fact, instead.

    ```crystal
    user = UserQuery.find(user_id)

    # Preload the user's tasks
    user_with_tasks = UserQuery.preload_tasks(user)
    ```

    It can even be used to load associations on a collection of records.

    ```crystal
    users = UserQuery.new.age(30)

    # Preload the users' tasks
    users_with_tasks = UserQuery.preload_tasks(users)
    ```

    ### Without preloading

    Sometimes you have a single model and don’t need to preload items. Or maybe you *can’t* preload because the
    model record is already loaded. In those cases you can use the association name with `!`:

    ```crystal
    task = TaskQuery.first
    # Returns the associated author and does not trigger a preload error
    task.user!
    ```

    #{permalink(ANCHOR_RELOADING)}
    ## Reloading Data

    Reloading a model can be useful when you've loaded a model, but then there is a change to the data.

    ```crystal
    author = AuthorQuery.find(5)

    # Let's say the Author's profile picture is hidden
    author.hide_avatar #=> true

    # If this database value is updated...
    SaveAuthor.update!(author, hide_avatar: false)

    # We can reload to get the new value
    author.reload.hide_avatar #=> false
    ```

    When calling the `reload` method on the [model](#{Guides::Database::Models.path}), the original
    instance is not updated.

    ```crystal
    # The new value grabbed from the reloaded model
    author.reload.hide_avatar #=> false

    # The original value is still in place
    author.hide_avatar #=> true
    ```

    > The `reload` method requires a `primary_key`. `view` models that need this method will need to implement it.

    ### Adding preloads when reloading

    You can also use the `reload` method to preload associations. For example, if you
    have a post, and want to preload comments, you can use `reload` with a block.

    ```crystal
    # `post` is a recently updated record.
    # We want to get all of the author names that commented on this `post`.

    # This is not preloaded, and can lead to performance issues
    post.comments.map(&.author.name)

    # Preload the comments and authors for better performance
    post.reload(&.preload_comments(CommentQuery.new.preload_authors))
      .comments.map(&.author.name)
    ```

    Read up on [preloading associations](#{Guides::Database::Querying.path(anchor: Guides::Database::Querying::ANCHOR_PRELOADING)})
    for more information.

    ## No results

    Avram gives you a `none` method to return no results. This can be helpful when under
    certain conditions you want the results to be empty.

    ```crystal
    UserQuery.new.none
    ```

    > This method does not return an empty array immediately. You can still chain other query methods,
    > but it will always return no records. For example: `UserQuery.new.none.first` will never return a result

    ## Named Scopes

    Chaining multiple query methods can be hard to read, tedious, and error prone. If you are making a
    complex query more than once, or want to give a query a label, named scopes are a great alternative.

    ```crystal
    class UserQuery < User::BaseQuery
      def adults
        age.gte(18)
      end

      def search(name)
        ilike("\#{name}%")
      end
    end

    UserQuery.new.adults.search("Sal")
    ```

    ### Using with associations

    ```crystal
    class UserQuery < User::BaseQuery
      def recently_completed_admin_tasks
        task_query = TaskQuery.new.completed(true).updated_at.gte(1.day.ago)

        admin(true).where_tasks(task_query)
      end
    end

    # Then to use it
    UserQuery.new.recently_completed_admin_tasks
    ```

    When adding an associated query (like `task_query`), Avram will handle adding the join
    for you. By default, this is an `INNER JOIN`, but if you need to customize that, you can
    set the `auto_inner_join` option to `false`.

    ```crystal
    def recently_completed_admin_tasks
      task_query = TaskQuery.new.completed(true).updated_at.gte(1.day.ago)

      # Tell the `where_tasks` to skip adding the `inner_join` so we can
      # use the `left_join_tasks` instead.
      admin(true)
        .left_join_tasks
        .where_tasks(task_query, auto_inner_join: false)
    end
    ```

    ### Queries with defaults

    You can also set defaults for your query objects which could be an ordering, named scope, or whatever you may need.

    ```crystal
    class AdminQuery < User::BaseQuery

      def initialize
        defaults &.admin(true).name.asc_order
      end
    end

    # Will always query WHERE admin = true ORDER BY name ASC
    AdminQuery.new
    ```

    > The `defaults` method is private scoped. It's only meant to be used in the `initialize` method of your class.

    ## Resetting Queries

    If you need to remove parts of the SQL query after the query has been built, Avram gives you
    a few reset methods for that.

    ### Reset where

    The `reset_where` method takes a block where you call the name of the column you want to remove
    from your query.

    ```crystal
    # SELECT * FROM users WHERE name = 'Billy' AND signed_up < '2 days ago'
    user_query = UserQuery.new.name("Billy").signed_up.lt(2.days.ago)

    # The `name = 'Billy'` is removed
    # SELECT * FROM users WHERE signed_up < '2 days ago'
    user_query.reset_where(&.name)
    ```

    ### Reset order

    ```crystal
    user_query = UserQuery.new.age.desc_order

    # This will remove the `ORDER BY age DESC`
    user_query.reset_order
    ```

    ### Reset limit

    ```crystal
    user_query = UserQuery.new.limit(10)

    # This will remove the `LIMIT 10`
    user_query.reset_limit
    ```

    ### Reset offset

    ```crystal
    user_query = UserQuery.new.offset(25)

    # This will remove the `OFFSET 25`
    user_query.reset_offset
    ```

    ## Complex Queries

    If you need more complex queries that Avram may not support, you can run
    [raw SQL](#{Guides::Database::RawSql.path}).

    > Avram is designed to be type-safe. You should use caution when using the non type-safe methods,
    > or raw SQL.

    ## Debugging Queries

    Sometimes you may need to double check that the query you wrote outputs the SQL you expect.
    To do this, you can use the `to_sql` method which will return an array with the query, and args.

    ```crystal
    UserQuery.new
      .name("Stan")
      .age(45)
      .limit(1)
      .to_sql #=> ["SELECT COLUMNS FROM users WHERE users.name = $1 AND users.age = $2 LIMIT $3", "Stan", 45, 1]
    ```

    You can also use the `to_prepared_sql` method to combine your query and args. This is helpful when
    you need to copy and paste your query in to [psql](https://www.postgresql.org/docs/current/app-psql.html)
    directly during development when working with more complex queries.

    ```crystal
    UserQuery.new
      .where_posts(PostQuery.new.published(true).tags(["crystal", "lucky"]))
      .limit(10)
      .to_prepared_sql
    #=> "SELECT COLUMNS FROM users INNER JOIN posts ON users.id = posts.user_id WHERE posts.tags = '{"crystal", "lucky"}' LIMIT 10"
    ```

    If you'd prefer to see every query that is being run in your server logs, you can configure Avram's log level like this:

    ```crystal
    # This is often set in `config/database.cr`
    Avram::QueryLog.dexter.configure(:info)
    ```
    MD
  end
end
